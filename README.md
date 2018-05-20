# Rtop
A simple system monitoring dashboard script for shell utilising Linux system variables via `/Proc` virtual file system.

A beginner project I did to gain experience with Ruby inspired by `top` and [gtop](https://github.com/aksakalli/gtop). This project is nowhere complete, I plan to take it to completion and gaining more experience with ruby and CLI tools.

### Prerequisites
- Ruby
- Bundler

## Usage
- Just clone the repo
- Install dependecies

		bundle install
- Execute the script

		ruby rtop.rb
### Interactive Commands
	q - Quit the dashboard
	up arrow key - Scroll up process list
	down arrow key - Scroll down process list

## Contributing
If you'd like to contribute, please fork the repository and use a feature branch. Issues and Pull Requests are warmly welcome!

## To-Do
- [ ] Add interactive commands to navigate, search and kill processes
- [ ] Add networking stats in dashboard
- [ ] Add logger
- [ ] Add more colors to the dashboard :rainbow:

## License
Released under the [MIT License](https://github.com/psinghal20/rtop/blob/master/LICENSE)