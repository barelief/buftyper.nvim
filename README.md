

# buftyper.nvim

A Neovim plugin for typing practice that dims buffer text, reveals syntax highlighting as you type, and tracks your WPM and accuracy in real time.

<img width="1440" height="810" alt="buftype_code_2" src="https://github.com/user-attachments/assets/e7ad01e4-7846-4bb9-a3b6-f1a2051d26a7" />

## ✨ Features

- **Typing mode**: Activate to dim all text in the current buffer and type to reveal characters
- **Practice a selection**: Select text in visual mode to practice just that snippet — the rest of the buffer fades away
- **WPM tracking**: Live WPM calculation with rolling 5-second window
- **Accuracy tracking**: Percentage of correct keystrokes
- **Lualine integration**: Shows WPM in statusline when active
- **Visual feedback**: Yellow cursor marker, red error highlights for incorrect keys
- **Light & dark aware**: Dimming and word-hint colors adapt to your background

The current word is highlighted in dim orange and the next word in bright orange

<img width="1440" height="810" alt="buftype_description" src="https://github.com/user-attachments/assets/43cdf143-aee0-4f6c-b701-277105ffbeb4" />

## Installation

### lazy.nvim

```lua
{
  'barelief/buftyper.nvim',
  config = function()
    require('buftyper').setup({
      show_wpm = true,
      show_mode_indicator = false,
    })
  end
}
```

### packer.nvim

```lua
use {
  'barelief/buftyper.nvim',
  config = function()
    require('buftyper').setup()
  end
}
```

## Usage

The plugin provides the `:BufTyper` command and a default keymap:

- `:BufTyper` or `<leader>uB` - Activate typing mode for the whole buffer
- `<leader>uB` (visual mode) - Practice only the selected text
- `<Esc>` - Exit typing mode and show session summary

<img width="440" height="75" alt="image" src="https://github.com/user-attachments/assets/d1b29af8-c2d4-4aed-87d5-19ab8acafaf4" />

### Practice a selection

Select any text in visual mode and hit `<leader>uB` to practice just that snippet. The rest of the buffer fades into the background so you can focus on the selected lines, and the session ends automatically the moment you finish typing them. Works in both light and dark themes.

<img width="1440" height="810" alt="buftype_selection" src="https://github.com/user-attachments/assets/5c972d7c-ab5a-44b9-8f49-489acaefa46a" />

## Configuration

```lua
require('buftyper').setup({
  dim_hl = "BufTyperDim",           -- Highlight group for dimmed text
  error_hl = "BufTyperError",       -- Highlight group for errors
  done_hl = "BufTyperDone",         -- Highlight group for completed text
  show_wpm = true,                 -- Show WPM in lualine
  show_mode_indicator = false,     -- Set true if you don't use lualine
})
```

## License

MIT
