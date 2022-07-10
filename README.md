# mma8452q-spin
---------------

This is a P8X32A/Propeller, P2X8C4M64P/Propeller 2 driver object for the MMA8452Q 3DoF Accelerometer.

**IMPORTANT**: This software is meant to be used with the [spin-standard-library](https://github.com/avsa242/spin-standard-library) (P8X32A) or [p2-spin-standard-library](https://github.com/avsa242/p2-spin-standard-library) (P2X8C4M64P). Please install the applicable library first before attempting to use this code, otherwise you will be missing several files required to build the project.

## Salient Features

* I2C connection at up to 400kHz
* Supports default or alternate I2C address
* Manually or automatically set bias offsets (on-chip)
* Accelerometer built-in self-test
* Read accelerometer data in ADC words or micro-g's
* Set output data rate (in active and low-power operating modes)
* Set power state
* Set accelerometer full-scale
* Set interrupt flags, INT1/2 pin active state
* Set accelerometer data oversampling/power mode (in active and low-power operating modes)
* Output data filtering: high-pass
* Read flags: accelerometer data ready, data overrun, interrupts
* Orientation detection
* Click/Pulse/Tap detection
* Free-fall detection
* Inactivity detection/auto-sleep

## Requirements

P1/SPIN1:
* spin-standard-library
* 1 extra core/cog for the PASM I2C engine (none if bytecode-based engine is used)
* sensor.imu.common.spinh (provided by spin-standard-library)

P2/SPIN2:
* p2-spin-standard-library
* sensor.imu.common.spin2h (provided by p2-spin-standard-library)

## Compiler Compatibility

| Processor | Language | Compiler               | Backend     | Status                |
|-----------|----------|------------------------|-------------|-----------------------|
| P1        | SPIN1    | FlexSpin (5.9.13-beta) | Bytecode    | OK                    |
| P1        | SPIN1    | FlexSpin (5.9.13-beta) | Native code | OK                    |
| P1        | SPIN1    | OpenSpin (1.00.81)     | Bytecode    | Untested (deprecated) |
| P2        | SPIN2    | FlexSpin (5.9.13-beta) | NuCode      | OK                    |
| P2        | SPIN2    | FlexSpin (5.9.13-beta) | Native code | OK                    |
| P1        | SPIN1    | Brad's Spin Tool (any) | Bytecode    | Unsupported           |
| P1, P2    | SPIN1, 2 | Propeller Tool (any)   | Bytecode    | Unsupported           |
| P1, P2    | SPIN1, 2 | PNut (any)             | Bytecode    | Unsupported           |

## Limitations

* TBD

