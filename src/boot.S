.section ".text.boot"

.global _start
_start:
  mrs x1, mpidr_el1
  and x1, x1, #3
  cbz x1, 2f
1: wfe
  b 1b
2:
  // Load the _start symbol for our code and move the stack pointer to it
  ldr x1, =_start
  mov sp, x1
  // Load up the stack start address and stack size
  ldr x1, =__bss_start
  ldr w2, =__bss_size

// Zero out the stack. When stack is zeroed, jump to label 4
3: cbz w2, 4f
  // Move value from offset 8 in x1 to the zero register (discard register)
  str xzr, [x1], #8
  // Subtract 1 from w2 and store the result in w2
  sub w2, w2, #1
  // Keep doing this until stack size is zero, indicating a cleaned stack
  cbnz w2, 3b

// Call external kmain
4: bl kmain
  b 1b
