{
    --------------------------------------------
    Filename: core.con.mma8452q.spin
    Author: Jesse Burt
    Description: Low-level constants
    Copyright (c) 2021
    Started May 9, 2021
    Updated May 9, 2021
    See end of file for terms of use.
    --------------------------------------------
}

CON

' I2C Configuration
    I2C_MAX_FREQ        = 400_000                   ' device max I2C bus freq
    SLAVE_ADDR          = $1D << 1                  ' 7-bit format slave address
    T_POR               = 2_000                     ' startup time (usecs)

    DEVID_RESP          = $2A                       ' device ID expected response

' Register definitions
    STATUS              = $00
        ZYXOW           = 7
        ZOW             = 6
        YOW             = 5
        XOW             = 4
        ZYXDR           = 3
        ZDR             = 2
        YDR             = 1
        XDR             = 0
        ZYX_OW          = 1 << ZYXOW
        ZYX_DR          = 1 << ZYXDR

    OUT_X_MSB           = $01
    OUT_X_LSB           = $02
    OUT_Y_MSB           = $03
    OUT_Y_LSB           = $04
    OUT_Z_MSB           = $05
    OUT_Z_LSB           = $06
    SYSMOD              = $0B
    INT_SOURCE          = $0C
    WHO_AM_I            = $0D
    XYZ_DATA_CFG        = $0E
    HP_FILT_CUTOFF      = $0F
    PL_STATUS           = $10
    PL_CFG              = $11
    PL_COUNT            = $12
    PL_BF_ZCOMP         = $13
    P_L_THS_REG         = $14
    FF_MT_CFG           = $15
    FF_MT_SRC           = $16
    FF_MT_THS           = $17
    FF_MT_CNT           = $18
    TRANSIENT_CFG       = $1D
    TRANSIENT_SRC       = $1E
    TRANSIENT_THS       = $1F
    TRANSIENT_CNT       = $20
    PULSE_CFG           = $21
    PULSE_SRC           = $22
    PULSE_THSX          = $23
    PULSE_THSY          = $24
    PULSE_THSZ          = $25
    PULSE_TMLT          = $26
    PULSE_LTCY          = $27
    PULSE_WIND          = $28
    ASLP_CNT            = $29

    CTRL_REG1           = $2A
    CTRL_REG1_MASK      = $FF
        ASLP_RATE       = 6
        DR              = 3
        LNOISE          = 2
        F_READ          = 1
        ACTIVE          = 0
        ASLP_RATE_BITS  = %11
        DR_BITS         = %111
        ASLP_RATE_MASK  = (ASLP_RATE_BITS << ASLP_RATE) ^ CTRL_REG1_MASK
        DR_MASK         = (DR_BITS << DR) ^ CTRL_REG1_MASK
        LNOISE_MASK     = (1 << LNOISE) ^ CTRL_REG1_MASK
        F_READ_MASK     = (1 << F_READ) ^ CTRL_REG1_MASK
        ACTIVE_MASK     = 1 ^ CTRL_REG1_MASK

    CTRL_REG2           = $2B
    CTRL_REG2_MASK      = $DF
        ST              = 7
        RST             = 6
        SMODS           = 3
        SLPE            = 2
        MODS            = 0
        SMODS_BITS      = %11
        MODS_BITS       = %11
        ST_MASK         = (1 << ST) ^ CTRL_REG2_MASK
        RST_MASK        = (1 << RST) ^ CTRL_REG2_MASK
        SMODS_MASK      = (SMODS_BITS << SMODS) ^ CTRL_REG2_MASK
        SLPE_MASK       = (1 << SLPE) ^ CTRL_REG2_MASK
        MODS_MASK       = MODS_BITS ^ CTRL_REG2_MASK
        RESET           = 1 << RST

    CTRL_REG3           = $2C
    CTRL_REG4           = $2D
    CTRL_REG5           = $2E
    OFF_X               = $2F
    OFF_Y               = $30
    OFF_Z               = $31

PUB Null{}
' This is not a top-level object

