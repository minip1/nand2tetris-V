module main

import os
import strings

fn debug_log(msg string) {
	mut f := os.open_file('parser_debug.log', 'a+') or { return }
	f.writeln(msg) or {}
	f.close()
}

struct Token {
	typ string
	value string
}

struct Parser {
	tokens []Token
	mut:
		pos int
		out strings.Builder
}

fn main() {
	if os.args.len < 2 {
		println('Usage: ./parser fileT.xml')
		return
	}

	file_path := os.args[1]
	lines := os.read_lines(file_path) or {
		println('Failed to read $file_path')
		return
	}

	tokens := parse_tokens(lines)
	mut parser := Parser{
		tokens: tokens
		pos: 0
		out: strings.new_builder(10000)
	}

	parser.compile_class()

	out_path := file_path.replace('T.xml', '.xml')
	os.write_file(out_path, parser.out.str()) or {
		println('Failed to write $out_path')
	}
}

// ---------------------------------------------

fn parse_tokens(lines []string) []Token {
	mut tokens := []Token{}
	for i in 0 .. lines.len {
		mut line := lines[i].trim_space()
		if line == '<tokens>' || line == '</tokens>' || line.len == 0 {
			continue
		}
		
		// Handle XML entities
		line = line.replace('&lt;', '<')
		line = line.replace('&gt;', '>')
		line = line.replace('&amp;', '&')
		
		start_opt := line.index('>')
		if start_opt == none {
			continue
		}
		mut start := start_opt or { continue }
		start++
		end_opt := line.last_index('<')
		if end_opt == none {
			continue
		}
		end := end_opt or { continue }
		mut typ := line.all_before('>').trim('<> /')
		mut value := line[start..end]
		
		// Handle token type mapping
		if typ == 'string_constant' {
			typ = 'stringConstant'
		} else if typ == 'integer_constant' {
			typ = 'integerConstant'
		} else {
			value = value.trim_space()
		}
		
		tokens << Token{typ: typ, value: value}
	}
	return tokens
}

// ---------------------------------------------

fn (mut p Parser) advance() Token {
	if p.pos >= p.tokens.len {
		return Token{typ: '', value: ''}
	}
	t := p.tokens[p.pos]
	p.pos++
	return t
}

fn (p Parser) peek() Token {
	if p.pos >= p.tokens.len {
		return Token{typ: '', value: ''}
	}
	return p.tokens[p.pos]
}

fn (mut p Parser) write_token() Token {
	t := p.advance()
	// Escape special characters for XML output in correct order
	mut value := t.value
	value = value.replace('&', '&amp;')
	value = value.replace('<', '&lt;')
	value = value.replace('>', '&gt;')
	p.out.writeln('  <${t.typ}> ${value} </${t.typ}>')
	return t
}

fn (mut p Parser) write_tag_start(tag string) {
	p.out.writeln('<$tag>')
}

fn (mut p Parser) write_tag_end(tag string) {
	p.out.writeln('</$tag>')
}

// ---------------------------------------------

fn (mut p Parser) compile_class() {
	p.write_tag_start('class')
	p.write_token() // 'class'
	p.write_token() // className
	p.write_token() // '{'

	for p.peek().value == 'static' || p.peek().value == 'field' {
		p.compile_class_var_dec()
	}

	for p.peek().value == 'constructor' || p.peek().value == 'function' || p.peek().value == 'method' {
		p.compile_subroutine()
	}

	p.write_token() // '}'
	p.write_tag_end('class')
}

fn (mut p Parser) compile_class_var_dec() {
	p.write_tag_start('classVarDec')
	p.write_token() // static/field
	p.write_token() // type
	p.write_token() // varName
	for p.peek().value == ',' {
		p.write_token() // ','
		p.write_token() // varName
	}
	p.write_token() // ';'
	p.write_tag_end('classVarDec')
}

fn (mut p Parser) compile_subroutine() {
	p.write_tag_start('subroutineDec')
	p.write_token() // constructor|function|method
	p.write_token() // void|type
	p.write_token() // subroutineName
	p.write_token() // '('
	p.compile_parameter_list()
	p.write_token() // ')'
	p.compile_subroutine_body()
	p.write_tag_end('subroutineDec')
}

fn (mut p Parser) compile_parameter_list() {
	p.write_tag_start('parameterList')
	if p.peek().value != ')' {
		p.write_token() // type
		p.write_token() // varName
		for p.peek().value == ',' {
			p.write_token() // ','
			p.write_token() // type
			p.write_token() // varName
		}
	}
	p.write_tag_end('parameterList')
}

fn (mut p Parser) compile_subroutine_body() {
	p.write_tag_start('subroutineBody')
	p.write_token() // '{'
	for p.peek().value == 'var' {
		p.compile_var_dec()
	}
	p.compile_statements()
	p.write_token() // '}'
	p.write_tag_end('subroutineBody')
}

fn (mut p Parser) compile_var_dec() {
	p.write_tag_start('varDec')
	p.write_token() // 'var'
	p.write_token() // type
	p.write_token() // varName
	for p.peek().value == ',' {
		p.write_token() // ','
		p.write_token() // varName
	}
	p.write_token() // ';'
	p.write_tag_end('varDec')
}

fn (mut p Parser) compile_statements() {
	p.write_tag_start('statements')
	for p.peek().value == 'let' || p.peek().value == 'if' || p.peek().value == 'while' || 
	   p.peek().value == 'do' || p.peek().value == 'return' {
		match p.peek().value {
			'let' { p.compile_let() }
			'if' { p.compile_if() }
			'while' { p.compile_while() }
			'do' { p.compile_do() }
			'return' { p.compile_return() }
			else {}
		}
	}
	p.write_tag_end('statements')
}

fn (mut p Parser) compile_let() {
	p.write_tag_start('letStatement')
	p.write_token() // let
	p.write_token() // varName
	
	if p.peek().value == "[" {
		p.write_token() // '['
		p.compile_expression()
		p.write_token() // ']'
	}
	
	p.write_token() // '='
	p.compile_expression()
	p.write_token() // ';'
	p.write_tag_end('letStatement')
}

fn (mut p Parser) compile_if() {
	p.write_tag_start('ifStatement')
	p.write_token() // if
	p.write_token() // '('
	p.compile_expression()
	p.write_token() // ')'
	p.write_token() // '{'
	p.compile_statements()
	p.write_token() // '}'
	if p.peek().value == 'else' {
		p.write_token() // else
		p.write_token() // '{'
		p.compile_statements()
		p.write_token() // '}'
	}
	p.write_tag_end('ifStatement')
}

fn (mut p Parser) compile_while() {
	p.write_tag_start('whileStatement')
	p.write_token() // while
	p.write_token() // '('
	p.compile_expression()
	p.write_token() // ')'
	p.write_token() // '{'
	p.compile_statements()
	p.write_token() // '}'
	p.write_tag_end('whileStatement')
}

fn (mut p Parser) compile_do() {
	p.write_tag_start('doStatement')
	p.write_token() // do
	p.write_token() // subroutineName/className/varName
	next := p.peek()
	if next.value == '(' {
		p.write_token() // '('
		p.compile_expression_list()
		p.write_token() // ')'
	} else if next.value == '.' {
		p.write_token() // '.'
		p.write_token() // subroutineName
		p.write_token() // '('
		p.compile_expression_list()
		p.write_token() // ')'
	}
	p.write_token() // ';'
	p.write_tag_end('doStatement')
}

fn (mut p Parser) compile_return() {
	p.write_tag_start('returnStatement')
	p.write_token() // return
	if p.peek().value != ';' {
		p.compile_expression()
	}
	p.write_token() // ';'
	p.write_tag_end('returnStatement')
}

fn (mut p Parser) compile_expression() {
	p.write_tag_start('expression')
	p.compile_term()
	for p.peek().value in ['+', '-', '*', '/', '&', '|', '<', '>', '='] {
		p.write_token() // op
		p.compile_term()
	}
	p.write_tag_end('expression')
}

fn (mut p Parser) compile_term() {
	p.write_tag_start('term')
	t := p.peek()
	if t.value == '-' || t.value == '~' {
		p.write_token() // unary op
		p.compile_term()
	} else if t.value == '(' {
		p.write_token() // '('
		p.compile_expression()
		p.write_token() // ')'
	} else {
		tok := p.write_token()
		if tok.typ == 'identifier' {
			next := p.peek()
			if next.value == '[' {
				// Array access
				p.write_token() // '['
				p.compile_expression()
				p.write_token() // ']'
			} else if next.value == '(' {
				// Subroutine call
				p.write_token() // '('
				p.compile_expression_list()
				p.write_token() // ')'
			} else if next.value == '.' {
				// Method call
				p.write_token() // '.'
				p.write_token() // subroutineName
				p.write_token() // '('
				p.compile_expression_list()
				p.write_token() // ')'
			}
		}
	}
	p.write_tag_end('term')
}

fn (mut p Parser) compile_expression_list() {
	p.write_tag_start('expressionList')
	if p.peek().value != ')' {
		p.compile_expression()
		for p.peek().value == ',' {
			p.write_token() // ','
			p.compile_expression()
		}
	}
	p.write_tag_end('expressionList')
}