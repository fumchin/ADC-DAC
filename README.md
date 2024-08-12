

# MCU DSP Project
* NCTU microcontroller final project
* This project focuses on developing an embedded system that captures, processes, and displays waveform signals through the use of ADC (Analog-to-Digital Converter) and DAC (Digital-to-Analog Converter) modules. The system integrates these signals and provides user control and feedback through a keyboard module and multiple display outputs.


## System Overview

### Functionality

1. **Signal Acquisition**:
   - The ADC module captures signals from a waveform generator, converting them into digital data for processing within the microcontroller.

2. **Signal Integration**:
   - The system integrates the acquired digital signal using fixed-point arithmetic and outputs the processed signal via the DAC module.

3. **User Interaction**:
   - Users can adjust the sampling frequency of the ADC using a keyboard module. The keyboard also allows switching between displaying the peak and trough values of the waveform.

4. **Display Modules**:
   - **LED Display**: Shows the peak value's sign (positive or negative) of the output waveform.
   - **Seven-Segment Displays**: Four displays show the peak or trough values in both integer and decimal format.

### Modules and Components

- **ADC Module**: Captures the input waveform signal for processing.
- **DAC Module**: Outputs the integrated waveform.
- **Keyboard Module**: Controls the sampling frequency and display options.
- **LED Module**: Displays the sign of the peak value.
- **Seven-Segment Displays**: Display the numerical value of the peak or trough.

### Features

- **Adjustable Sampling Rate**: Allows users to modify the ADC sampling rate via the keyboard.
- **Real-time Display**: Real-time visualization of waveform peaks and troughs.
- **Fixed-Point Arithmetic**: Ensures efficient processing of the waveform data.
