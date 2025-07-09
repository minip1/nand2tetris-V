module main

import os

enum TokenType {
	keyword
	symbol
	identifier
	integer_constant
	string_constant
}

struct Token {
	typ TokenType
	value string
}

const keywords = [
	'class', 'constructor', 'function', 'method', 'field', 'static', 'var',
	'int', 'char', 'boolean', 'void', 'true', 'false', 'null', 'this',
	'let', 'do', 'if', 'else', 'while', 'return'
]

const symbols = ['{', '}', '(', ')', '[', ']', '.', ',', ';', '+', '-', '*', '/', '&', '|', '<', '>', '=', '~']

fn escape_symbol(c string) string {
	return match c {
		'<' { '&lt;' }
		'>' { '&gt;' }
		'"' { '&quot;' }
		'&' { '&amp;' }
		else { c }
	}
}

fn is_symbol(c u8) bool {
	return c.ascii_str() in symbols
}

fn is_whitespace(c u8) bool {
	return c == ` ` || c == `\n` || c == `\r` || c == `\t`
}

fn is_digit(c u8) bool {
	return c >= `0` && c <= `9`
}

fn is_letter_or_underscore(c u8) bool {
	return (c >= `a` && c <= `z`) || (c >= `A` && c <= `Z`) || c == `_`
}

fn is_identifier_char(c u8) bool {
	return is_letter_or_underscore(c) || is_digit(c)
}

fn tokenize(source string) []Token {
	mut tokens := []Token{}
	mut i := 0

	for i < source.len {
		c := source[i]

		if is_whitespace(c) {
			i++
			continue
		}

		if c == `/` && i + 1 < source.len && source[i+1] == `/` {
			i += 2
			for i < source.len && source[i] != `\n` {
				i++
			}
			continue
		}

		if c == `/` && i + 1 < source.len && source[i+1] == `*` {
			i += 2
			for i + 1 < source.len && !(source[i] == `*` && source[i+1] == `/`) {
				i++
			}
			i += 2
			continue
		}

		if is_symbol(c) {
			tokens << Token{
				typ: TokenType.symbol
				value: c.ascii_str()
			}
			i++
			continue
		}

		if c == `"` {
			mut j := i + 1
			mut s := ''
			for j < source.len && source[j] != `"` {
				s += source[j].ascii_str()
				j++
			}
			tokens << Token{
				typ: TokenType.string_constant
				value: s
			}
			i = j + 1
			continue
		}

		if is_digit(c) {
			mut j := i
			for j < source.len && is_digit(source[j]) {
				j++
			}
			tokens << Token{
				typ: TokenType.integer_constant
				value: source[i..j]
			}
			i = j
			continue
		}

		if is_letter_or_underscore(c) {
			mut j := i
			for j < source.len && is_identifier_char(source[j]) {
				j++
			}
			word := source[i..j]
			if word in keywords {
				tokens << Token{
					typ: TokenType.keyword
					value: word
				}
			} else {
				tokens << Token{
					typ: TokenType.identifier
					value: word
				}
			}
			i = j
			continue
		}

		i++
	}
	return tokens
}

fn main() {
	if os.args.len < 2 {
		println('Usage: ./main path_to_file_or_folder')
		return
	}

	input_path := os.args[1]
	mut files := []string{}

	if os.is_dir(input_path) {
		all := os.ls(input_path) or {
			println('Failed to list directory')
			return
		}
		for file in all {
			if file.ends_with('.jack') {
				files << input_path + '/' + file
			}
		}
	} else {
		files << input_path
	}

	for file in files {
		source := os.read_file(file) or {
			println('Failed to read $file')
			continue
		}
		mut output := '<tokens>\n'
		for token in tokenize(source) {
			output += '<$token.typ.str()> ${escape_symbol(token.value)} </$token.typ.str()>\n'
		}
		output += '</tokens>\n'
		os.write_file(file.replace('.jack', 'T.xml'), output) or {
			println('Failed to write output for $file')
		}
	}
}
