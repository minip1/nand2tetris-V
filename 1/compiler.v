module main

import os

fn main() {
    if os.args.len < 2 {
        println('Usage: program.exe <folder_path>')
        return
    }

    folder_path := os.args[1]

    if !os.exists(folder_path) || !os.is_dir(folder_path) {
        println('Error: "$folder_path" is not a valid folder path')
        return
    }

    files := os.ls(folder_path) or {
        println('Error reading folder: $err')
        return
    }

    mut result := []string{}
    mut found_vm_file := false
    mut file_result := ''
    for file in files {
        if file.ends_with('.vm') {
            file_result = file
            found_vm_file = true
            full_path := os.join_path(folder_path, file)
            lines := os.read_lines(full_path) or {
                println('Failed to read $file: $err')
                continue
            }

            println('Converting $file:')
            for line in lines {
                trimmed_line := line.trim_space()
                hack_line := translate_vm_to_hack(trimmed_line)
                if hack_line != '' {
                    println(hack_line)
                    result << hack_line
                }
            }
        }
    }

    if !found_vm_file {
        println('No .vm files found in the specified folder.')
        return
    } else {
        file_result = file_result.replace('.vm', '.asm')
        println('Writing to $file_result')
        output_path := os.join_path(folder_path, file_result)
        os.write_file(output_path, result.join('\n')) or {
            println('Failed to write output: $err')
            return
        }
        println('Hack code written to $output_path')
    }
}

fn translate_vm_to_hack(vm_line string) string {
    line := vm_line.trim_space()
    if line == '' || line.starts_with('//') {
        return ''
    }
    // function command
    if line.starts_with('function ') {
        parts := line.split(' ')
     if parts.len == 3 {
        func_name := parts[1]
        n_vars := parts[2].int()
        mut code := '($func_name)'
        for _ in 0 .. n_vars {
            code += '\n@0\nD=A\n@SP\nA=M\nM=D\n@SP\nM=M+1'
        }
        return code
    }
}
    // constant
    if line.starts_with('push constant ') {
        parts := line.split(' ')
        if parts.len == 3 {
            num := parts[2]
            return '@$num\nD=A\n@SP\nA=M\nM=D\n@SP\nM=M+1'
        }
    }

    // local 
    if line.starts_with('pop local ') {
        parts := line.split(' ')
        if parts.len == 3 {
            num := parts[2]
            return '@$num\nAM=M-1\nD=M\n@LCL\nA=M+0\nM=D'
        }
    }
    if line.starts_with('push local ') {
        parts := line.split(' ')
        if parts.len == 3 {
            num := parts[2]
            return '@$num\nD=A\n@LCL\nA=M+D\nD=M\n@SP\nA=M\nM=D\n@SP\nM=M+1'
        }
    }

    // argument
    if line.starts_with('pop argument ') {
        parts := line.split(' ')
        if parts.len == 3 {
            num := parts[2]
            return '@$num\nAM=M-1\nD=M\n@ARG\nA=M+0\nM=D'
        }
    }
    if line.starts_with('push argument ') {
        parts := line.split(' ')
        if parts.len == 3 {
            num := parts[2]
            return '@$num\nD=A\n@ARG\nA=M+D\nD=M\n@SP\nA=M\nM=D\n@SP\nM=M+1'
        }
    }

    // this
    if line.starts_with('pop this ') {
        parts := line.split(' ')
        if parts.len == 3 {
            num := parts[2]
            return '@$num\nAM=M-1\nD=M\n@THIS\nA=M+0\nM=D'
        }
    }
    if line.starts_with('push this ') {
        parts := line.split(' ')
        if parts.len == 3 {
            num := parts[2]
            return '@$num\nD=A\n@THIS\nA=M+D\nD=M\n@SP\nA=M\nM=D\n@SP\nM=M+1'
        }
    }

    // that
    if line.starts_with('pop that ') {
        parts := line.split(' ')
        if parts.len == 3 {
            num := parts[2]
            return '@$num\nAM=M-1\nD=M\n@THAT\nA=M+0\nM=D'
        }
    }
    if line.starts_with('push that ') {
        parts := line.split(' ')
        if parts.len == 3 {
            num := parts[2]
            return '@$num\nD=A\n@THAT\nA=M+D\nD=M\n@SP\nA=M\nM=D\n@SP\nM=M+1'
        }
    }

    // pointer
    if line.starts_with('push pointer ') {
        parts := line.split(' ')
        if parts.len == 3 {
            num := parts[2]
            return '@$num\nD=A\n@R3\nA=M+D\nD=M\n@SP\nA=M\nM=D\n@SP\nM=M+1'
        }
    }

    // temp
    if line.starts_with('push temp ') {
        parts := line.split(' ')
        if parts.len == 3 {
            num := parts[2]
            return '@$num\nD=A\n@R5\nA=M+D\nD=M\n@SP\nA=M\nM=D\n@SP\nM=M+1'
        }
    }
    if line.starts_with('pop temp ') {
        parts := line.split(' ')
        if parts.len == 3 {
            num := parts[2]
            return '@$num\nAM=M-1\nD=M\n@R5\nA=M+D\nM=D'
        }
    }

    // pointer
    if line.starts_with('pop pointer ') {
        parts := line.split(' ')
        if parts.len == 3 {
            num := parts[2]
            return '@$num\nAM=M-1\nD=M\n@R3\nA=M+D\nM=D'
        }
    }

    // static
    if line.starts_with('push static ') {
        parts := line.split(' ')
        if parts.len == 3 {
            num := parts[2]
            return '@$num\nD=A\n@R16\nA=M+D\nD=M\n@SP\nA=M\nM=D\n@SP\nM=M+1'
        }
    }
    if line.starts_with('pop static ') {
        parts := line.split(' ')
        if parts.len == 3 {
            num := parts[2]
            return '@$num\nAM=M-1\nD=M\n@R16\nA=M+D\nM=D'
        }
    }

    return match line {
        'add' { '@SP\nAM=M-1\nD=M\nA=A-1\nM=M+D' }
        'sub' { '@SP\nAM=M-1\nD=M\nA=A-1\nM=M-D' }
        'neg' { '@SP\nA=M-1\nM=-M' }
        'and' { '@SP\nAM=M-1\nD=M\nA=A-1\nM=M&D' }
        'or' { '@SP\nAM=M-1\nD=M\nA=A-1\nM=M|D' }
        'not' { '@SP\nA=M-1\nM=!M' }
        'eq' {
            '@SP\nAM=M-1\nD=M\nA=A-1\nD=M-D\n@TRUE\nD;JEQ\n@SP\nA=M-1\nM=0\n@END\n0;JMP\n(TRUE)\n@SP\nA=M-1\nM=-1\n(END)'
        }
        'gt' {
            '@SP\nAM=M-1\nD=M\nA=A-1\nD=M-D\n@TRUE\nD;JGT\n@SP\nA=M-1\nM=0\n@END\n0;JMP\n(TRUE)\n@SP\nA=M-1\nM=-1\n(END)'
        }
        'lt' {
            '@SP\nAM=M-1\nD=M\nA=A-1\nD=M-D\n@TRUE\nD;JLT\n@SP\nA=M-1\nM=0\n@END\n0;JMP\n(TRUE)\n@SP\nA=M-1\nM=-1\n(END)'
        }
        else { '// Unknown command: $line' }
    }
}
