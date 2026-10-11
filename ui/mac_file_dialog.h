// Native macOS file chooser (NSOpenPanel / NSSavePanel), run non-modally: start() returns at once and poll() reports
// the choice once the panel closes, so no plugin thread ever waits for the user.  [main-thread]
#pragma once
#include <memory>
#include <string>

namespace eiii::ui {

class file_dialog
{
public:
	enum class kind { open_file, open_folder, save_file };
	~file_dialog() { cancel(); }
	// start: a folder to open in, or a file (its folder; for save_file also the proposed name)
	bool start(kind k, std::string const &title, std::string const &start);
	bool running() const { return m_state != nullptr; }
	bool poll(std::string &result);         // true once closed; result = the chosen path ("" = cancelled)
	void cancel();
	struct state;
private:
	std::shared_ptr<state> m_state;
};

} // namespace eiii::ui
