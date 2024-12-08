.section .text
.globl _start
_start:
    # Start in M mode
    
    
    # Set up the trap handler for S mode
    la t0, trap_handler       # Load address of trap handler
    csrw stvec, t0            # Set S mode trap handler address

    # Delegate exceptions to S mode
    li t0, 0x4
    csrw medeleg, t0          # Delegate illegal instr exceptions to S mode
    
    csrr t0, mstatus		# read the value of mstatus register
	
	li t1, 0x1800			# load this immediate in t1 0b1100000000000 
	or t0, t0, t1			# set the 11th and 12th bit of mstatus register to 11
	csrw mstatus, t0		# write t0 to mstatus register
    
    j switch
    

	



trap_handler:
    csrr t0, scause           # Get cause of the exception
    csrr t1, sepc             # Get the program counter where exception occurred
    li t2, 2                  # Illegal instruction cause code
    beq t0, t2, handle_illegal_instruction
    j trap_exit               # Exit trap for unhandled exceptions

handle_illegal_instruction:
    # Handle illegal instruction here
   
    addi t1, t1, 4            # Increment PC to skip invalid instruction
    csrw sepc, t1             # Update the exception program counter
    j trap_exit

trap_exit:
    sret                      # Return from trap
    

switch:
# Set up M mode for U mode entry
    csrr t0, mstatus		# read the value of mstatus register
    li t1, ~0x1800			
    and t0, t0, t1			# set the 11th and 12th bit of mstatus register to 00
    csrw mstatus, t0		
    la t0, user_mode_start
    csrw mepc, t0             # Set U mode entry point
    mret                      # Switch to U mode

user_mode_start:
    # Illegal instruction to generate exception
    
    mret
    li a0, 10               # Exit code 0 (success)
    #li a7, 93              # Exit syscall number
    #ecall                  # Make syscall to exit
    li t0, 1               # Exit code
    la t1, tohost          # Load address of tohost
    sw t0, 0(t1)           # Write exit code to tohost
    ecall


write_tohost:
li x1, 1
sw x1, tohost, t5
j write_tohost





.align 12
.section ".tohost","aw",@progbits;                            
.align 4; .global tohost; tohost: .dword 0;                     
.align 4; .global fromhost; fromhost: .dword 0;

