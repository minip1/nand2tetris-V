module main

import os

struct Command {
    typ string
    arg1 string
    arg2 int
}

fn main() {
    if os.args.len < 2 {
        println('Usage: vmtranslator input.vm or vmtranslator directory')
        return
    }

    input_path := os.args[1]
    mut vm_files := []string{}

    if os.is_dir(input_path) {
        println('Processing directory: $input_path')
        files := os.ls(input_path) or {
            println('Failed to list directory: $err')
            return
        }
        for file in files {
            if file.ends_with('.vm') {
                vm_files << os.join_path(input_path, file)
            }
        }
        if vm_files.len == 0 {
            println('No .vm files found in directory')
            return
        }
        output_path := os.join_path(input_path, os.file_name(input_path) + '.asm')
        translate_files(vm_files, output_path)
    } else if input_path.ends_with('.vm') {
        println('Processing single file: $input_path')
        vm_files << input_path
        output_path := input_path.replace('.vm', '.asm')
        translate_files(vm_files, output_path)
    } else {
        println('Input must be a .vm file or a directory containing .vm files')
    }
}

fn translate_files(vm_files []string, output_path string) {
    println('Generating output: $output_path')
    
    mut result := []string{}
    mut code_writer := CodeWriter{}
    
    // Add bootstrap code for directory processing
    if vm_files.len > 1 {
        result << '// Bootstrap initialization'
        result << '@256'
        result << 'D=A'
        result << '@SP'
        result << 'M=D'
        result << code_writer.translate_function('call', 'Sys.init', 0)
    }
    
    for file in vm_files {
        println('  Processing $file')
        code_writer.current_class = os.file_name(file).replace('.vm', '')
        
        // Read input file
        lines := os.read_lines(file) or {
            println('Failed to read $file: $err')
            continue
        }

        mut parser := Parser{}
        
        for line in lines {
            // Skip comments and empty lines
            cleaned := line.all_before('//').trim_space()
            if cleaned == '' {
                continue
            }

            // Parse command
            cmd := parser.parse(cleaned) or {
                println('Error parsing line: $line')
                println(err)
                continue
            }

            // Translate to assembly
            asm_code := code_writer.translate(cmd) or {
                println('Error translating command: $cmd')
                println(err)
                continue
            }
            result << '// Source: ${os.file_name(file)} - $cleaned'
            result << asm_code
        }
    }

    // Write output
    mut output := ''
    for asm_line in result {
        output += asm_line + '\n'
    }
    os.write_file(output_path, output) or {
        println('Failed to write output: $err')
        return
    }

    println('Successfully created $output_path with ${result.len} assembly instructions')
}

struct Parser {
}

fn (p Parser) parse(line string) !Command {
    parts := line.split(' ')
    mut clean_parts := []string{}
    for part in parts {
        if part != '' {
            clean_parts << part
        }
    }

    match clean_parts.len {
        0 { return error('Empty command') }
        1 { return Command{typ: clean_parts[0], arg1: '', arg2: 0} }
        2 { return Command{typ: clean_parts[0], arg1: clean_parts[1], arg2: 0} }
        3 { return Command{typ: clean_parts[0], arg1: clean_parts[1], arg2: clean_parts[2].int()} }
        else { return error('Invalid command format: $line') }
    }
}

struct CodeWriter {
    mut:
        label_counter int
        current_fn string = 'global'
        current_class string
}

fn (mut cw CodeWriter) translate(cmd Command) !string {
    return match cmd.typ {
        'push' { cw.translate_push(cmd.arg1, cmd.arg2) }
        'pop' { cw.translate_pop(cmd.arg1, cmd.arg2) }
        'add', 'sub', 'neg', 'eq', 'gt', 'lt', 'and', 'or', 'not' {
            cw.translate_arithmetic(cmd.typ)
        }
        'label', 'goto', 'if-goto' {
            cw.translate_branching(cmd.typ, cmd.arg1)
        }
        'function' { 
            cw.current_fn = cmd.arg1
            cw.translate_function(cmd.typ, cmd.arg1, cmd.arg2)
        }
        'call', 'return' {
            cw.translate_function(cmd.typ, cmd.arg1, cmd.arg2)
        }
        else {
            error('Unsupported command: $cmd.typ')
        }
    }
}

fn (mut cw CodeWriter) translate_push(segment string, index int) string {
    match segment {
        'constant' {
            return '
            @$index  // Load constant
            D=A
            @SP     // Push to stack
            A=M
            M=D
            @SP     // Increment SP
            M=M+1'
        }
        'local', 'argument', 'this', 'that' {
            addr := match segment {
                'local'    { 'LCL' }
                'argument' { 'ARG' }
                'this'     { 'THIS' }
                'that'     { 'THAT' }
                else       { '0' }
            }
            return '
            @$addr  // $segment $index
            D=M
            @$index
            A=D+A
            D=M
            @SP
            A=M
            M=D
            @SP
            M=M+1'
        }
        'temp' {
            return '
            @5      // temp $index
            D=A
            @$index
            A=D+A
            D=M
            @SP
            A=M
            M=D
            @SP
            M=M+1'
        }
        'pointer' {
            return '
            @${if index == 0 { 'THIS' } else { 'THAT' }}  // pointer $index
            D=M
            @SP
            A=M
            M=D
            @SP
            M=M+1'
        }
        'static' {
            return '
            @${cw.current_class}.$index  // static $index
            D=M
            @SP
            A=M
            M=D
            @SP
            M=M+1'
        }
        else {
            return '// Unsupported push segment: $segment'
        }
    }
}

fn (mut cw CodeWriter) translate_pop(segment string, index int) string {
    match segment {
        'local', 'argument', 'this', 'that' {
            addr := match segment {
                'local'    { 'LCL' }
                'argument' { 'ARG' }
                'this'     { 'THIS' }
                'that'     { 'THAT' }
                else       { '0' }
            }
            return '
            @$addr  // Calculate address for $segment $index
            D=M
            @$index
            D=D+A
            @R13
            M=D     // Store address in R13
            @SP     // Pop from stack
            M=M-1
            A=M
            D=M
            @R13    // Get address from R13
            A=M
            M=D     // Store value'
        }
        'temp' {
            return '
            @5      // temp $index
            D=A
            @$index
            D=D+A
            @R13
            M=D
            @SP     // pop
            M=M-1
            A=M
            D=M
            @R13
            A=M
            M=D'
        }
        'pointer' {
            return '
            @SP     // pointer $index (pop)
            M=M-1
            A=M
            D=M
            @${if index == 0 { 'THIS' } else { 'THAT' }}
            M=D'
        }
        'static' {
            return '
            @SP     // static $index (pop)
            M=M-1
            A=M
            D=M
            @${cw.current_class}.$index
            M=D'
        }
        else {
            return '// Unsupported pop segment: $segment'
        }
    }
}

fn (mut cw CodeWriter) translate_arithmetic(op string) string {
    return match op {
        'add' { '
            @SP     // add
            M=M-1
            A=M
            D=M
            @SP
            M=M-1
            A=M
            M=M+D
            @SP
            M=M+1'
        }
        'sub' { '
            @SP     // sub
            M=M-1
            A=M
            D=M
            @SP
            M=M-1
            A=M
            M=M-D
            @SP
            M=M+1'
        }
        'neg' { '
            @SP     // neg
            M=M-1
            A=M
            M=-M
            @SP
            M=M+1'
        }
        'eq', 'gt', 'lt' { 
            cw.label_counter++
            true_label := '${cw.current_fn}_TRUE_${cw.label_counter}'
            end_label := '${cw.current_fn}_END_${cw.label_counter}'
            jump := match op {
                'eq' { 'JEQ' }
                'gt' { 'JGT' }
                'lt' { 'JLT' }
                else { 'JMP' }
            }
            return '
            @SP     // $op
            M=M-1
            A=M
            D=M
            @SP
            M=M-1
            A=M
            D=M-D
            @$true_label
            D;$jump
            @SP
            A=M
            M=0
            @$end_label
            0;JMP
            ($true_label)
            @SP
            A=M
            M=-1
            ($end_label)
            @SP
            M=M+1'
        }
        'and' { '
            @SP     // and
            M=M-1
            A=M
            D=M
            @SP
            M=M-1
            A=M
            M=M&D
            @SP
            M=M+1'
        }
        'or' { '
            @SP     // or
            M=M-1
            A=M
            D=M
            @SP
            M=M-1
            A=M
            M=M|D
            @SP
            M=M+1'
        }
        'not' { '
            @SP     // not
            M=M-1
            A=M
            M=!M
            @SP
            M=M+1'
        }
        else { '// Unsupported arithmetic operation: $op' }
    }
}

fn (mut cw CodeWriter) translate_branching(cmd string, label string) string {
    full_label := '${cw.current_fn}_$label'
    return match cmd {
        'label' { '($full_label)' }
        'goto' { '
            @$full_label
            0;JMP'
        }
        'if-goto' { '
            @SP     // if-goto $full_label
            M=M-1
            A=M
            D=M
            @$full_label
            D;JNE'
        }
        else { '// Unsupported branching command: $cmd' }
    }
}

fn (mut cw CodeWriter) translate_function(cmd string, name string, n_vars int) string {
    match cmd {
        'function' {
            cw.current_fn = name
            mut init_code := '($name) // function $name $n_vars\n'
            for _ in 0 .. n_vars {
                init_code += '
                @SP     // Initialize local var
                A=M
                M=0
                @SP
                M=M+1'
            }
            return init_code
        }
        'call' {
            return_label := '${name}_RET_${cw.label_counter}'
            cw.label_counter++
            return '
            @$return_label // call $name $n_vars
            D=A
            @SP
            A=M
            M=D
            @SP
            M=M+1
            @LCL
            D=M
            @SP
            A=M
            M=D
            @SP
            M=M+1
            @ARG
            D=M
            @SP
            A=M
            M=D
            @SP
            M=M+1
            @THIS
            D=M
            @SP
            A=M
            M=D
            @SP
            M=M+1
            @THAT
            D=M
            @SP
            A=M
            M=D
            @SP
            M=M+1
            @SP
            D=M
            @5
            D=D-A
            @$n_vars
            D=D-A
            @ARG
            M=D
            @SP
            D=M
            @LCL
            M=D
            @$name
            0;JMP
            ($return_label)'
        }
        'return' {
            return '
            // FRAME = LCL
            @LCL
            D=M
            @R13
            M=D
            
            // RET = *(FRAME-5)
            @5
            A=D-A
            D=M
            @R14
            M=D
            
            // *ARG = pop()
            @SP
            M=M-1
            A=M
            D=M
            @ARG
            A=M
            M=D
            
            // SP = ARG+1
            @ARG
            D=M+1
            @SP
            M=D
            
            // THAT = *(FRAME-1)
            @R13
            M=M-1
            A=M
            D=M
            @THAT
            M=D
            
            // THIS = *(FRAME-2)
            @R13
            M=M-1
            A=M
            D=M
            @THIS
            M=D
            
            // ARG = *(FRAME-3)
            @R13
            M=M-1
            A=M
            D=M
            @ARG
            M=D
            
            // LCL = *(FRAME-4)
            @R13
            M=M-1
            A=M
            D=M
            @LCL
            M=D
            
            // goto RET
            @R14
            A=M
            0;JMP'
        }
        else { 
            return '// Unsupported function command: $cmd'
        }
    }
}