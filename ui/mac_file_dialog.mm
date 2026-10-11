// Native macOS file chooser — see mac_file_dialog.h.  Compiled without ARC.
#include "mac_file_dialog.h"
#import <Cocoa/Cocoa.h>

namespace eiii::ui {

struct file_dialog::state
{
	NSSavePanel *panel = nil;           // NSOpenPanel derives from NSSavePanel
	bool done = false;
	std::string result;
	~state() { [panel release]; }
};

bool file_dialog::start(kind k, std::string const &title, std::string const &start)
{
	if (m_state) return false;
	auto st = std::make_shared<state>();
	NSString *const path = [NSString stringWithUTF8String:start.c_str()];
	BOOL is_dir = NO;
	bool const exists = !start.empty() && [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&is_dir];
	NSString *const dir = exists && is_dir ? path : [path stringByDeletingLastPathComponent];
	if (k == kind::save_file)
	{
		NSSavePanel *const p = [[NSSavePanel savePanel] retain];
		p.canCreateDirectories = YES;
		if (!start.empty() && !is_dir) p.nameFieldStringValue = [path lastPathComponent];
		st->panel = p;
	}
	else
	{
		NSOpenPanel *const p = [[NSOpenPanel openPanel] retain];
		p.canChooseFiles = k == kind::open_file;
		p.canChooseDirectories = k == kind::open_folder;
		p.allowsMultipleSelection = NO;
		p.resolvesAliases = YES;
		st->panel = p;
	}
	st->panel.title = [NSString stringWithUTF8String:title.c_str()];
	st->panel.message = st->panel.title;
	if (dir.length) st->panel.directoryURL = [NSURL fileURLWithPath:dir isDirectory:YES];
	std::weak_ptr<state> weak = st;
	[st->panel beginWithCompletionHandler:^(NSModalResponse r) {
		auto s = weak.lock();
		if (!s) return;                                  // cancelled from our side
		if (r == NSModalResponseOK && s->panel.URL.path) s->result = s->panel.URL.path.fileSystemRepresentation;
		s->done = true;
	}];
	m_state = st;
	return true;
}

bool file_dialog::poll(std::string &result)
{
	if (!m_state || !m_state->done) return false;
	result = m_state->result;
	m_state.reset();
	return true;
}

void file_dialog::cancel()
{
	if (!m_state) return;
	auto st = std::move(m_state);
	if (!st->done) [st->panel cancel:nil];
}

} // namespace eiii::ui
