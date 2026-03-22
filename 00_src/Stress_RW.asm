START:
li x10, 0x1000 #Base addr
li x11, 64 #Data
li x12, 0xB0BACAFE #Data
jal x1, STORE
jal x1, LOAD

DONE: 
    nop
    nop
    nop
    j DONE


STORE:
    # x10: base addr
    # x11: number of bytes
    # x12: store data

    mv t0, x10        # current address
    mv t1, x11        # remaining bytes
    mv t2, x12        # data

LOOP_STORE:
    beqz t1, DONE_STORE

    sw t2, 0(t0)

    addi t0, t0, 4    # addr += 4
    addi t1, t1, -4   # bytes -= 4

    j LOOP_STORE

DONE_STORE:
    jalr x0, x1, 0
    
LOAD:
    # x10: base addr
    # x11: number of bytes
    # x13: read data (optional return)

    mv t0, x10            # current address
    mv t1, x11            # remaining bytes
    li t2, 0xB0BACAFE     # expected value

LOOP_LOAD:
    beqz t1, DONE_LOAD
    lw t3, 0(t0)          # read
    bne t3, t2, ERROR     # so sánh với 0xB0BACAFE
    addi t0, t0, 4        # tăng offset
    addi t1, t1, -4       # trừ số bytes
    j LOOP_LOAD

DONE_LOAD:
    jalr x0, x1, 0
    
ERROR:
    j ERROR    # loop vô hạn để debug