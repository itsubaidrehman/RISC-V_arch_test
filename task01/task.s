.section .text
.global _start

_start:
    # Initialize stack pointer
    la sp, stack_top

    # Set up trap handler address
    la t0, trap_handler
    csrw mtvec, t0         # Set mtvec to trap handler
    

    # Call mode switch function to go to Supervisor mode
    li a0, 0               # Argument 0: Supervisor mode
    jal switch_mode

    # Test Supervisor mode with ecall
    ecall

    # Switch to User mode
    li a0, 1               # Argument 1: User mode
    jal switch_mode

    # Test User mode with ecall
    ecall


    # Switch back to Machine mode
    #li t2, 0                # Clear mstatus to switch to Machine mode
    #csrw mstatus, t2
    
    
    # Switch back to Machine mode
    csrr t2, mstatus
    li t3, ~(0x3 << 11)    # Create mask to clear MPP bits
    and t2, t2, t3         # Clear MPP bits (returns to Machine mode)
    csrw mstatus, t2

    # Clean exit
    li a0, 10               # Exit code 0 (success)
    #li a7, 93              # Exit syscall number
    #ecall                  # Make syscall to exit
    li t0, 1               # Exit code
    la t1, tohost          # Load address of tohost
    sw t0, 0(t1)           # Write exit code to tohost

# Switch mode function
switch_mode:
    li t0, 0x80           # Load the mstatus register address to t0
    li t1, 0              # Load 0 (to switch to Supervisor)
    beq a0, t1, set_supervisor_mode
    li t1, 1              # Load 1 (to switch to User)
    beq a0, t1, set_user_mode
    j end                 # Jump to end if argument is not 0 or 1

set_supervisor_mode:
    csrr t2, mstatus
    li t3, 0x1 << 11  # Set the bits to switch to Supervisor
    #li t3, 0xFFFFEFFF
    or t2, t2, t3
    #li t3, 0x
    #or t2, t2, t3
    csrw mstatus, t2
    
    ret

set_user_mode:
    csrr t2, mstatus
    li t3, 0x2 << 11  # Set the bits to switch to User
    or t2, t2, t3
    csrw mstatus, t2
    ret

end:
    ret

# Trap handler
trap_handler:
    # Save registers that we'll use
    addi sp, sp, -16
    sw t0, 0(sp)
    sw t1, 4(sp)
    sw t2, 8(sp)
    sw t3, 12(sp)

   csrr t2, mstatus
    csrr t0, mcause        # Get the trap cause
    li t1, 8               # SUPERVISOR_ECALL code (0x8)
    beq t0, t1, handle_supervisor_ecall
    li t1, 9               # USER_ECALL code (0x9)
    beq t0, t1, handle_user_ecall
    j return_from_trap     # Return if not an ecall

handle_supervisor_ecall:
    # Code to handle Supervisor ecall
    j return_from_trap

handle_user_ecall:
    # Code to switch to Supervisor mode
    csrr t2, mstatus
    li t3, ~(0x3 << 11)   # Create mask to clear MPP bits
    and t2, t2, t3        # Clear existing MPP bits
    li t3, 0x1 << 11      # Set MPP to 01 for Supervisor mode
    or t2, t2, t3
    csrw mstatus, t2
    j return_from_trap

return_from_trap:
    # Restore saved registers
    lw t0, 0(sp)
    lw t1, 4(sp)
    lw t2, 8(sp)
    lw t3, 12(sp)
    addi sp, sp, 16
    csrr t0, mepc
    addi t0, t0, 4       # Skip ecall instruction
    csrw mepc, t0
    mret                   # Return from trap

.section .data
    .align 4
    .space 4096           # Reserve 4KB for stack
stack_top:                # Label for top of stack




write_tohost:
li x1, 1
sw x1, tohost, t5
j write_tohost
.data 

n: .word 5




.align 12
.section ".tohost","aw",@progbits;                            
.align 4; .global tohost; tohost: .dword 0;                     
.align 4; .global fromhost; fromhost: .dword 0;

