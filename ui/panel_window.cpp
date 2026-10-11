// panel_window — see panel_window.h.
#include "panel_window.h"

namespace eiii::ui {

bool panel_window::open(void *parent, int w, int h, std::string &error)
{
	m_view.set_size(w, h);
	m_win.cb.down = [this](int x, int y, int b) { m_view.mouse_down(float(x), float(y), b, m_ui); };
	m_win.cb.up = [this](int x, int y, int b) { m_view.mouse_up(float(x), float(y), b, m_ui); };
	m_win.cb.move = [this](int x, int y) { m_view.mouse_move(float(x), float(y), m_ui); };
	m_win.cb.wheel = [this](int x, int y, int s) { m_view.wheel(float(x), float(y), s, m_ui); };
	m_win.cb.focus_out = [this] { m_view.focus_lost(m_ui); m_ui.release_all(); };
	m_win.cb.expose = [this] { m_full = true; };
	m_win.cb.resized = [this](int nw, int nh) { m_view.set_size(nw, nh); m_full = true; };   // canvas pixels
	if (!m_win.open(parent, w, h, error)) return false;
	m_full = true;
	return true;
}

void panel_window::set_size(int w, int h)
{
	m_win.set_size(w, h);              // -> resized() with the pixel size
	m_full = true;
}

void panel_window::tick()
{
	if (!m_win.is_open()) return;
	m_ui.poll();
	recti const r = m_view.render(m_frame, m_ui, m_full);
	if (m_full) m_win.present(m_frame, { 0, 0, m_frame.w, m_frame.h });
	else if (!r.empty()) m_win.present(m_frame, r);
	m_full = false;
}

} // namespace eiii::ui
