# ai.vim

A minimal Neovim plugin for text generation and editing with Anthropic Claude models.

## Features
- Complete text in insert mode
- Generate new text with prompts
- Edit existing text in-place
- Streaming completions
- Simple interface: use `<Ctrl-A>` or `:AI <prompt>`
- Works with code and regular text

## Installing
```vim
Plug 'stevedylandev/ai.vim'
```

Requires `$ANTHROPIC_API_KEY` environment variable and `curl`.

## Usage
- Press `<Ctrl-Enter>` in insert mode to complete text
- Use `:AI <prompt>` to generate new text
- Select text and run `:AI <instruction>` to edit it
- Create custom shortcuts for common prompts

## Disclaimers
- Verify all AI-generated content for accuracy
- Text is sent to Anthropic - avoid sensitive information

## Acknowledgements

This is a fork of [`aduros/ai.vim`](https://github.com/aduros/ai.vim) but uses Anthropic models instead
