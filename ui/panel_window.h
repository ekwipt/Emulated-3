// panel_window: the rack panel in a Cocoa view embedded in the host's plugin window.
// Input arrives through Cocoa on the main thread; tick() polls the machine and redraws what changed — call it from
// the main thread on a timer (~30-60 Hz).  All machine interaction goes through the panel_adapter.
#pragma once
#include "panel_view.h"
#include "mac_window.h"

namespace eiii::ui {

class panel_window
{
public:
	explicit panel_window(panel_adapter &ui) : m_ui(ui) { }
	bool open(void *parent, int w, int h, std::string &error);   // parent: NSView *; w, h in points
	void close() { m_win.close(); }
	bool is_open() const { return m_win.is_open(); }
	void tick();
	void set_size(int w, int h);                                 // points
	void show(bool visible) { m_win.show(visible); }
	panel_view &view() { return m_view; }
	canvas const &frame() const { return m_frame; }
private:
	panel_adapter &m_ui;
	panel_view m_view;
	mac_window m_win;
	canvas m_frame;
	bool m_full = true;
};

} // namespace eiii::ui
