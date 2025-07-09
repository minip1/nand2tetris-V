module main

import os

// -------------------------------
// Tokenizer
// -------------------------------
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

		// Handle comments
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

		// Handle symbols
		if is_symbol(c) {
			tokens << Token{
				typ: .symbol
				value: c.ascii_str()
			}
			i++
			continue
		}

		// Handle string constants
		if c == `"` {
			mut j := i + 1
			mut s := ''
			for j < source.len && source[j] != `"` {
				s += source[j].ascii_str()
				j++
			}
			tokens << Token{
				typ: .string_constant
				value: s
			}
			i = j + 1
			continue
		}

		// Handle integer constants
		if is_digit(c) {
			mut j := i
			for j < source.len && is_digit(source[j]) {
				j++
			}
			tokens << Token{
				typ: .integer_constant
				value: source[i..j]
			}
			i = j
			continue
		}

		// Handle keywords and identifiers
		if is_letter_or_underscore(c) {
			mut j := i
			for j < source.len && is_identifier_char(source[j]) {
				j++
			}
			word := source[i..j]
			if word in keywords {
				tokens << Token{
					typ: .keyword
					value: word
				}
			} else {
				tokens << Token{
					typ: .identifier
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

// -------------------------------
// Symbol Table
// -------------------------------
enum Kind {
	static
	field
	arg
	var
	none
}

struct Symbol {
	name string
	typ  string
	kind Kind
	idx  int
}

struct SymbolTable {
mut:
	class_table map[string]Symbol
	sub_table   map[string]Symbol
	class_idx   map[Kind]int
	sub_idx     map[Kind]int
}

fn new_symbol_table() SymbolTable {
	return SymbolTable{
		class_table: map[string]Symbol{}
		sub_table: map[string]Symbol{}
		class_idx: {
			.static: 0
			.field: 0
		}
		sub_idx: {
			.arg: 0
			.var: 0
		}
	}
}

fn (mut st SymbolTable) start_subroutine() {
	st.sub_table = map[string]Symbol{}
	st.sub_idx = {
		.arg: 0
		.var: 0
	}
}

fn (mut st SymbolTable) define(name string, typ string, kind Kind) {
	match kind {
		.static, .field {
			idx := st.class_idx[kind]
			st.class_table[name] = Symbol{name, typ, kind, idx}
			st.class_idx[kind] = idx + 1
		}
		.arg, .var {
			idx := st.sub_idx[kind]
			st.sub_table[name] = Symbol{name, typ, kind, idx}
			st.sub_idx[kind] = idx + 1
		}
		else {}
	}
}

fn (st SymbolTable) var_count(kind Kind) int {
	return match kind {
		.static, .field { st.class_idx[kind] }
		.arg, .var { st.sub_idx[kind] }
		else { 0 }
	}
}

fn (st SymbolTable) kind_of(name string) Kind {
	if sym := st.sub_table[name] {
		return sym.kind
	}
	if sym := st.class_table[name] {
		return sym.kind
	}
	return .none
}

fn (st SymbolTable) type_of(name string) string {
	if sym := st.sub_table[name] {
		return sym.typ
	}
	if sym := st.class_table[name] {
		return sym.typ
	}
	return ''
}

fn (st SymbolTable) index_of(name string) int {
	if sym := st.sub_table[name] {
		return sym.idx
	}
	if sym := st.class_table[name] {
		return sym.idx
	}
	return -1
}

// -------------------------------
// VM Writer
// -------------------------------
struct VMWriter {
mut:
	f os.File
}

fn new_vm_writer(path string) !VMWriter {
	f := os.create(path)!
	return VMWriter{f}
}

fn (mut vw VMWriter) write_push(segment string, index int) {
	vw.f.writeln('push ${segment} ${index}') or { panic(err) }
}

fn (mut vw VMWriter) write_pop(segment string, index int) {
	vw.f.writeln('pop ${segment} ${index}') or { panic(err) }
}

fn (mut vw VMWriter) write_arithmetic(command string) {
	vw.f.writeln(command) or { panic(err) }
}

fn (mut vw VMWriter) write_label(label string) {
	vw.f.writeln('label ${label}') or { panic(err) }
}

fn (mut vw VMWriter) write_goto(label string) {
	vw.f.writeln('goto ${label}') or { panic(err) }
}

fn (mut vw VMWriter) write_if(label string) {
	vw.f.writeln('if-goto ${label}') or { panic(err) }
}

fn (mut vw VMWriter) write_call(name string, n_args int) {
	vw.f.writeln('call ${name} ${n_args}') or { panic(err) }
}

fn (mut vw VMWriter) write_function(name string, n_locals int) {
	vw.f.writeln('function ${name} ${n_locals}') or { panic(err) }
}

fn (mut vw VMWriter) write_return() {
	vw.f.writeln('return') or { panic(err) }
}

fn (mut vw VMWriter) close() {
	vw.f.close()
}

// -------------------------------
// Parser
// -------------------------------
struct Parser {
	tokens []Token
mut:
	pos int
	st SymbolTable
	class_name string
	writer VMWriter
	label_counter int
}

fn (mut p Parser) next_label() string {
	p.label_counter++
	return 'L${p.label_counter}'
}

fn (mut p Parser) advance() Token {
	if p.pos >= p.tokens.len {
		return Token{typ: .symbol, value: ''}
	}
	t := p.tokens[p.pos]
	p.pos++
	return t
}

fn (p Parser) peek() Token {
	if p.pos >= p.tokens.len {
		return Token{typ: .symbol, value: ''}
	}
	return p.tokens[p.pos]
}

fn (mut p Parser) expect(value string) {
	t := p.advance()
	if t.value != value {
		panic('Expected ${value} but got ${t.value}')
	}
}

fn (mut p Parser) compile_class() {
	p.expect('class')
	p.class_name = p.advance().value // className
	p.expect('{')

	// Class variable declarations
	for p.peek().value in ['static', 'field'] {
		p.compile_class_var_dec()
	}

	// Subroutines
	for p.peek().value in ['constructor', 'function', 'method'] {
		p.compile_subroutine()
	}

	p.expect('}')
}

fn (mut p Parser) compile_class_var_dec() {
	kind_str := p.advance().value
	typ := p.advance().value
	name := p.advance().value

	kind := match kind_str {
		'static' { Kind.static }
		'field' { Kind.field }
		else { Kind.none }
	}
	p.st.define(name, typ, kind)

	for p.peek().value == ',' {
		p.advance() // ','
		name2 := p.advance().value
		p.st.define(name2, typ, kind)
	}
	p.expect(';')
}

fn (mut p Parser) compile_subroutine() {
	p.st.start_subroutine()
	sub_type := p.advance().value
	p.advance() // skip return type
	sub_name := p.advance().value
	full_name := '${p.class_name}.${sub_name}'

	// Handle 'this' for methods
	if sub_type == 'method' {
		p.st.define('this', p.class_name, .arg)
	}

	p.expect('(')
	p.compile_parameter_list()
	p.expect(')')

	// Subroutine body
	p.expect('{')
	
	// Local variables
	for p.peek().value == 'var' {
		p.compile_var_dec()
	}

	// Write function declaration
	n_locals := p.st.var_count(.var)
	p.writer.write_function(full_name, n_locals)

	// Constructor memory allocation
	if sub_type == 'constructor' {
		n_fields := p.st.var_count(.field)
		p.writer.write_push('constant', n_fields)
		p.writer.write_call('Memory.alloc', 1)
		p.writer.write_pop('pointer', 0)
	}
	// Method setup
	else if sub_type == 'method' {
		p.writer.write_push('argument', 0)
		p.writer.write_pop('pointer', 0)
	}

	p.compile_statements()
	p.expect('}')
}

fn (mut p Parser) compile_parameter_list() {
	if p.peek().value == ')' { return }

	typ := p.advance().value
	name := p.advance().value
	p.st.define(name, typ, .arg)

	for p.peek().value == ',' {
		p.advance() // ','
		typ2 := p.advance().value
		name2 := p.advance().value
		p.st.define(name2, typ2, .arg)
	}
}

fn (mut p Parser) compile_var_dec() {
	p.expect('var')
	typ := p.advance().value
	name := p.advance().value
	p.st.define(name, typ, .var)

	for p.peek().value == ',' {
		p.advance() // ','
		name2 := p.advance().value
		p.st.define(name2, typ, .var)
	}
	p.expect(';')
}

fn (mut p Parser) compile_statements() {
	for {
		match p.peek().value {
			'let' { p.compile_let() }
			'if' { p.compile_if() }
			'while' { p.compile_while() }
			'do' { p.compile_do() }
			'return' { p.compile_return() }
			else { break }
		}
	}
}

fn (mut p Parser) compile_let() {
	p.expect('let')
	name := p.advance().value
	
	// Handle array access
	is_array := p.peek().value == '['
	if is_array {
		p.expect('[')
		p.compile_expression()
		p.expect(']')
		
		// Get array base address
		kind := p.st.kind_of(name)
		idx := p.st.index_of(name)
		match kind {
			.field { p.writer.write_push('this', idx) }
			.static { p.writer.write_push('static', idx) }
			.arg { p.writer.write_push('argument', idx) }
			.var { p.writer.write_push('local', idx) }
			else {}
		}
		
		p.writer.write_arithmetic('add')
	}

	p.expect('=')
	p.compile_expression()
	p.expect(';')

	if is_array {
		p.writer.write_pop('temp', 0)
		p.writer.write_pop('pointer', 1)
		p.writer.write_push('temp', 0)
		p.writer.write_pop('that', 0)
	} else {
		kind := p.st.kind_of(name)
		idx := p.st.index_of(name)
		match kind {
			.field { p.writer.write_pop('this', idx) }
			.static { p.writer.write_pop('static', idx) }
			.arg { p.writer.write_pop('argument', idx) }
			.var { p.writer.write_pop('local', idx) }
			else {}
		}
	}
}

fn (mut p Parser) compile_if() {
	p.expect('if')
	p.expect('(')
	p.compile_expression()
	p.expect(')')
	
	else_label := p.next_label()
	end_label := p.next_label()
	
	p.writer.write_arithmetic('not')
	p.writer.write_if(else_label)
	
	p.expect('{')
	p.compile_statements()
	p.expect('}')
	
	p.writer.write_goto(end_label)
	p.writer.write_label(else_label)
	
	if p.peek().value == 'else' {
		p.expect('else')
		p.expect('{')
		p.compile_statements()
		p.expect('}')
	}
	
	p.writer.write_label(end_label)
}

fn (mut p Parser) compile_while() {
	start_label := p.next_label()
	end_label := p.next_label()
	
	p.writer.write_label(start_label)
	p.expect('while')
	p.expect('(')
	p.compile_expression()
	p.expect(')')
	
	p.writer.write_arithmetic('not')
	p.writer.write_if(end_label)
	
	p.expect('{')
	p.compile_statements()
	p.expect('}')
	
	p.writer.write_goto(start_label)
	p.writer.write_label(end_label)
}

fn (mut p Parser) compile_do() {
	p.expect('do')
	p.compile_subroutine_call()
	p.expect(';')
	
	// Pop return value (void functions return 0)
	p.writer.write_pop('temp', 0)
}

fn (mut p Parser) compile_return() {
	p.expect('return')
	if p.peek().value != ';' {
		p.compile_expression()
	} else {
		// Void functions return 0
		p.writer.write_push('constant', 0)
	}
	p.expect(';')
	p.writer.write_return()
}

fn (mut p Parser) compile_expression() {
	p.compile_term()
	
	for p.peek().value in ['+', '-', '*', '/', '&', '|', '<', '>', '='] {
		op := p.advance().value
		p.compile_term()
		
		match op {
			'+' { p.writer.write_arithmetic('add') }
			'-' { p.writer.write_arithmetic('sub') }
			'*' { p.writer.write_call('Math.multiply', 2) }
			'/' { p.writer.write_call('Math.divide', 2) }
			'&' { p.writer.write_arithmetic('and') }
			'|' { p.writer.write_arithmetic('or') }
			'<' { p.writer.write_arithmetic('lt') }
			'>' { p.writer.write_arithmetic('gt') }
			'=' { p.writer.write_arithmetic('eq') }
			else {}
		}
	}
}

fn (mut p Parser) compile_term() {
	token := p.peek()
	
	match token.typ {
		.integer_constant {
			p.advance()
			p.writer.write_push('constant', token.value.int())
		}
		.string_constant {
			p.advance()
			// Create new string object
			str := token.value
			p.writer.write_push('constant', str.len)
			p.writer.write_call('String.new', 1)
			for c in str {
				p.writer.write_push('constant', c)
				p.writer.write_call('String.appendChar', 2)
			}
		}
		.keyword {
			p.advance()
			match token.value {
				'true' {
					p.writer.write_push('constant', 1)
					p.writer.write_arithmetic('neg')
				}
				'false', 'null' { p.writer.write_push('constant', 0) }
				'this' { p.writer.write_push('pointer', 0) }
				else {}
			}
		}
		.symbol {
			if token.value == '(' {
				p.advance()
				p.compile_expression()
				p.expect(')')
			} else if token.value in ['-', '~'] {
				op := p.advance().value
				p.compile_term()
				if op == '-' {
					p.writer.write_arithmetic('neg')
				} else {
					p.writer.write_arithmetic('not')
				}
			}
		}
		.identifier {
			name := p.advance().value
			next := p.peek()
			
			// Array access
			if next.value == '[' {
				p.expect('[')
				p.compile_expression()
				p.expect(']')
				
				// Get array base address
				kind := p.st.kind_of(name)
				idx := p.st.index_of(name)
				match kind {
					.field { p.writer.write_push('this', idx) }
					.static { p.writer.write_push('static', idx) }
					.arg { p.writer.write_push('argument', idx) }
					.var { p.writer.write_push('local', idx) }
					else {}
				}
				
				p.writer.write_arithmetic('add')
				p.writer.write_pop('pointer', 1)
				p.writer.write_push('that', 0)
			}
			// Subroutine call
			else if next.value == '(' || next.value == '.' {
				p.compile_subroutine_call_with_name(name)
			}
			// Simple variable
			else {
				kind := p.st.kind_of(name)
				idx := p.st.index_of(name)
				match kind {
					.field { p.writer.write_push('this', idx) }
					.static { p.writer.write_push('static', idx) }
					.arg { p.writer.write_push('argument', idx) }
					.var { p.writer.write_push('local', idx) }
					else {}
				}
			}
		}
	}
}

fn (mut p Parser) compile_subroutine_call() {
	name := p.advance().value
	p.compile_subroutine_call_with_name(name)
}

fn (mut p Parser) compile_subroutine_call_with_name(name string) {
	mut n_args := 0
	mut full_name := ''
	
	if p.peek().value == '(' {
		// Method call on current object
		p.expect('(')
		p.writer.write_push('pointer', 0) // Push this
		n_args = p.compile_expression_list() + 1
		p.expect(')')
		full_name = '${p.class_name}.${name}'
	} else if p.peek().value == '.' {
		p.expect('.')
		method_name := p.advance().value
		
		// Check if name is an object
		obj_type := p.st.type_of(name)
		if obj_type != '' {
			// Method call on object
			kind := p.st.kind_of(name)
			idx := p.st.index_of(name)
			match kind {
				.field { p.writer.write_push('this', idx) }
				.static { p.writer.write_push('static', idx) }
				.arg { p.writer.write_push('argument', idx) }
				.var { p.writer.write_push('local', idx) }
				else {}
			}
			n_args = p.compile_expression_list() + 1
			full_name = '${obj_type}.${method_name}'
		} else {
			// Function call
			n_args = p.compile_expression_list()
			full_name = '${name}.${method_name}'
		}
	} else {
		panic('Expected ( or . in subroutine call')
	}
	
	p.writer.write_call(full_name, n_args)
}

fn (mut p Parser) compile_expression_list() int {
	mut n_args := 0
	
	if p.peek().value != ')' {
		p.compile_expression()
		n_args++
		
		for p.peek().value == ',' {
			p.advance()
			p.compile_expression()
			n_args++
		}
	}
	
	return n_args
}

// -------------------------------
// Main Program
// -------------------------------
fn main() {
	if os.args.len < 2 {
		println('Usage: ./jack_compiler path_to_file_or_folder')
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
				files << os.join_path(input_path, file)
			}
		}
	} else {
		files << input_path
	}

	for file in files {
		// Tokenize
		source := os.read_file(file) or {
			println('Failed to read $file')
			continue
		}
		tokens := tokenize(source)

		// Generate VM code
		vm_file := file.replace('.jack', '.vm')
		mut writer := new_vm_writer(vm_file) or {
			println('Failed to create VM writer for $vm_file')
			continue
		}
		defer {
			writer.close()
		}

		mut parser := Parser{
			tokens: tokens
			pos: 0
			st: new_symbol_table()
			writer: writer
			label_counter: 0
		}

		parser.compile_class()
		println('Compiled $file to $vm_file')
	}
}