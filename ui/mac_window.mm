// Cocoa view for the panel — see mac_window.h.
// The NSView subclass is registered at runtime under a name unique to this loaded image: the VST3 and the AU are
// separate bundles that one host may load side by side (and unload), so a fixed Objective-C class name would collide.
// Compiled without ARC.
#include "mac_window.h"
#import <Cocoa/Cocoa.h>
#include <objc/runtime.h>
#include <objc/message.h>
#include <algorithm>
#include <cmath>
#include <cstring>
#include <vector>

namespace eiii::ui {

struct mac_window::impl
{
	mac_window *owner = nullptr;
	NSView *view = nil;
	id key_observer = nil;
	NSTrackingArea *tracking = nil;
	std::vector<uint32_t> buf;                  // 0x00RRGGBB, little-endian = B G R x in memory
	CGContextRef bmp = nullptr;
	int bw = 0, bh = 0;                         // buffer size (canvas pixels)
	int pw = 0, ph = 0;                         // view size in pixels
	double wheel_acc = 0;

	double scale() const
	{
		if (view && view.window) return [view convertSizeToBacking:NSMakeSize(1, 1)].width;
		NSScreen *s = [NSScreen mainScreen];
		return s ? s.backingScaleFactor : 1.0;
	}
	void free_bitmap() { if (bmp) CGContextRelease(bmp); bmp = nullptr; bw = bh = 0; }
	bool make_bitmap(int w, int h)
	{
		free_bitmap();
		buf.assign(size_t(w) * h, 0x141414);
		CGColorSpaceRef cs = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
		bmp = CGBitmapContextCreate(buf.data(), size_t(w), size_t(h), 8, size_t(w) * 4, cs, uint32_t(kCGImageAlphaNoneSkipFirst) | uint32_t(kCGBitmapByteOrder32Little));
		CGColorSpaceRelease(cs);
		if (!bmp) return false;
		bw = w; bh = h;
		return true;
	}
	// view size or backing scale changed: tell the owner the new canvas size
	void update_pixels()
	{
		if (!view) return;
		double const s = scale();
		NSSize const sz = view.bounds.size;
		int const nw = std::max(1, int(std::lround(sz.width * s))), nh = std::max(1, int(std::lround(sz.height * s)));
		if (nw == pw && nh == ph) return;
		pw = nw; ph = nh;
		if (owner->cb.resized) owner->cb.resized(pw, ph);
	}
	void to_pixels(NSEvent *e, int &x, int &y)
	{
		NSPoint const p = [view convertPoint:e.locationInWindow fromView:nil];   // flipped view: y down
		double const s = scale();
		x = int(std::floor(p.x * s)); y = int(std::floor(p.y * s));
	}
	void watch_window(NSWindow *w)
	{
		if (key_observer) { [[NSNotificationCenter defaultCenter] removeObserver:key_observer]; [key_observer release]; key_observer = nil; }
		if (!w) return;
		key_observer = [[[NSNotificationCenter defaultCenter] addObserverForName:NSWindowDidResignKeyNotification object:w queue:nil
			usingBlock:^(NSNotification *) { if (owner->cb.focus_out) owner->cb.focus_out(); }] retain];
	}
};

namespace {

ptrdiff_t g_impl_offset = 0;

mac_window::impl *impl_of(id self) { return *reinterpret_cast<mac_window::impl **>(reinterpret_cast<char *>(self) + g_impl_offset); }
void set_impl(id self, mac_window::impl *p) { *reinterpret_cast<mac_window::impl **>(reinterpret_cast<char *>(self) + g_impl_offset) = p; }

template <typename... A> void call_super(id self, SEL sel, A... a)
{
	objc_super sup = { self, [NSView class] };
	reinterpret_cast<void (*)(objc_super *, SEL, A...)>(objc_msgSendSuper)(&sup, sel, a...);
}

BOOL m_yes(id, SEL) { return YES; }
BOOL m_yes_ev(id, SEL, NSEvent *) { return YES; }

void m_draw(id self, SEL, NSRect)
{
	mac_window::impl *const m = impl_of(self);
	CGContextRef const ctx = [[NSGraphicsContext currentContext] CGContext];
	NSRect const b = [(NSView *)self bounds];
	if (!m || !m->bmp)
	{
		CGContextSetRGBFillColor(ctx, 0x14 / 255.0, 0x14 / 255.0, 0x14 / 255.0, 1);
		CGContextFillRect(ctx, b);
		return;
	}
	CGImageRef const img = CGBitmapContextCreateImage(m->bmp);
	CGContextSaveGState(ctx);
	CGContextSetInterpolationQuality(ctx, kCGInterpolationNone);
	CGContextTranslateCTM(ctx, 0, b.size.height);                   // the bitmap is top-down, the view is flipped
	CGContextScaleCTM(ctx, 1, -1);
	CGContextDrawImage(ctx, CGRectMake(0, 0, b.size.width, b.size.height), img);   // canvas = view size in pixels
	CGContextRestoreGState(ctx);
	CGImageRelease(img);
}

void m_mouse_down(id self, SEL, NSEvent *e)
{
	mac_window::impl *const m = impl_of(self);
	if (!m || !m->owner->cb.down) return;
	int x, y; m->to_pixels(e, x, y);
	m->owner->cb.down(x, y, 1);
}
void m_mouse_up(id self, SEL, NSEvent *e)
{
	mac_window::impl *const m = impl_of(self);
	if (!m || !m->owner->cb.up) return;
	int x, y; m->to_pixels(e, x, y);
	m->owner->cb.up(x, y, 1);
}
void m_mouse_move(id self, SEL, NSEvent *e)
{
	mac_window::impl *const m = impl_of(self);
	if (!m || !m->owner->cb.move) return;
	int x, y; m->to_pixels(e, x, y);
	m->owner->cb.move(x, y);
}
void m_scroll(id self, SEL, NSEvent *e)
{
	mac_window::impl *const m = impl_of(self);
	if (!m || !m->owner->cb.wheel) return;
	// one step per wheel notch; trackpads (precise deltas, in points) give one step per ~12 points
	m->wheel_acc += e.hasPreciseScrollingDeltas ? e.scrollingDeltaY / 12.0 : e.scrollingDeltaY;
	int const steps = int(m->wheel_acc);
	if (!steps) return;
	m->wheel_acc -= steps;
	int x, y; m->to_pixels(e, x, y);
	m->owner->cb.wheel(x, y, steps);
}
void m_backing_changed(id self, SEL sel)
{
	call_super(self, sel);
	if (mac_window::impl *const m = impl_of(self)) { m->update_pixels(); if (m->owner->cb.expose) m->owner->cb.expose(); }
}
void m_moved_to_window(id self, SEL sel)
{
	call_super(self, sel);
	if (mac_window::impl *const m = impl_of(self)) { m->watch_window([(NSView *)self window]); m->update_pixels(); if (m->owner->cb.expose) m->owner->cb.expose(); }
}
void m_set_frame_size(id self, SEL sel, NSSize sz)
{
	call_super(self, sel, sz);
	if (mac_window::impl *const m = impl_of(self)) m->update_pixels();
}

Class view_class()
{
	static Class cls = nil;
	if (cls) return cls;
	char name[96];
	for (int n = 0; !cls && n < 1000; ++n)
	{
		snprintf(name, sizeof name, "EIIIRackPanelView_%p_%d", static_cast<void *>(&g_impl_offset), n);
		if (!objc_getClass(name)) cls = objc_allocateClassPair([NSView class], name, 0);
	}
	if (!cls) return nil;
	class_addIvar(cls, "eiii_impl", sizeof(void *), uint8_t(std::log2(sizeof(void *))), "^v");
	class_addMethod(cls, @selector(isFlipped), IMP(m_yes), "c@:");
	class_addMethod(cls, @selector(isOpaque), IMP(m_yes), "c@:");
	class_addMethod(cls, @selector(acceptsFirstMouse:), IMP(m_yes_ev), "c@:@");
	std::string const draw_types = std::string("v@:") + @encode(NSRect);
	class_addMethod(cls, @selector(drawRect:), IMP(m_draw), draw_types.c_str());
	class_addMethod(cls, @selector(mouseDown:), IMP(m_mouse_down), "v@:@");
	class_addMethod(cls, @selector(mouseUp:), IMP(m_mouse_up), "v@:@");
	class_addMethod(cls, @selector(mouseDragged:), IMP(m_mouse_move), "v@:@");
	class_addMethod(cls, @selector(mouseMoved:), IMP(m_mouse_move), "v@:@");
	class_addMethod(cls, @selector(scrollWheel:), IMP(m_scroll), "v@:@");
	class_addMethod(cls, @selector(viewDidChangeBackingProperties), IMP(m_backing_changed), "v@:");
	class_addMethod(cls, @selector(viewDidMoveToWindow), IMP(m_moved_to_window), "v@:");
	std::string const size_types = std::string("v@:") + @encode(NSSize);
	class_addMethod(cls, @selector(setFrameSize:), IMP(m_set_frame_size), size_types.c_str());
	objc_registerClassPair(cls);
	g_impl_offset = ivar_getOffset(class_getInstanceVariable(cls, "eiii_impl"));
	return cls;
}

} // namespace

mac_window::mac_window() : m(new impl) { m->owner = this; }
mac_window::~mac_window() { close(); delete m; }
bool mac_window::is_open() const { return m->view != nil; }
int mac_window::pixel_width() const { return m->pw; }
int mac_window::pixel_height() const { return m->ph; }

bool mac_window::open(void *parent, int w, int h, std::string &error)
{
	close();
	NSView *const par = static_cast<NSView *>(parent);
	if (!par) { error = "no parent view"; return false; }
	Class const cls = view_class();
	if (!cls) { error = "cannot register the panel view class"; return false; }
	NSView *const v = [[cls alloc] initWithFrame:NSMakeRect(0, 0, w, h)];
	if (!v) { error = "cannot create the panel view"; return false; }
	set_impl(v, m);
	m->view = v;
	m->tracking = [[NSTrackingArea alloc] initWithRect:NSZeroRect options:NSTrackingMouseMoved | NSTrackingActiveAlways | NSTrackingInVisibleRect owner:v userInfo:nil];
	[v addTrackingArea:m->tracking];
	[par addSubview:v];                                               // -> viewDidMoveToWindow -> update_pixels
	m->update_pixels();
	return true;
}

void mac_window::close()
{
	if (!m->view) return;
	m->watch_window(nil);
	if (m->tracking) { [m->view removeTrackingArea:m->tracking]; [m->tracking release]; m->tracking = nil; }
	set_impl(m->view, nullptr);
	[m->view removeFromSuperview];
	[m->view release];
	m->view = nil;
	m->free_bitmap();
	m->buf.clear(); m->buf.shrink_to_fit();
	m->pw = m->ph = 0;
}

void mac_window::show(bool v)
{
	if (m->view) [m->view setHidden:!v];
}

void mac_window::set_size(int w, int h)
{
	if (!m->view) return;
	[m->view setFrameSize:NSMakeSize(w, h)];                          // -> update_pixels
}

void mac_window::present(canvas const &c, recti r)
{
	if (!m->view || r.empty() || c.w <= 0 || c.h <= 0) return;
	if (m->bw != c.w || m->bh != c.h) { if (!m->make_bitmap(c.w, c.h)) return; r = { 0, 0, c.w, c.h }; }
	r.x0 = std::max(0, r.x0); r.y0 = std::max(0, r.y0); r.x1 = std::min(c.w, r.x1); r.y1 = std::min(c.h, r.y1);
	if (r.empty()) return;
	for (int y = r.y0; y < r.y1; ++y)
		memcpy(&m->buf[size_t(y) * c.w + r.x0], &c.px[size_t(y) * c.w + r.x0], size_t(r.x1 - r.x0) * 4);
	double const s = m->pw > 0 ? double(m->pw) / m->view.bounds.size.width : 1.0;
	[m->view setNeedsDisplayInRect:NSMakeRect(std::floor(r.x0 / s) - 1, std::floor(r.y0 / s) - 1, std::ceil((r.x1 - r.x0) / s) + 2, std::ceil((r.y1 - r.y0) / s) + 2)];
}

} // namespace eiii::ui
