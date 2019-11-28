import UIKit
import Charts
import Accelerate
import PlaygroundSupport

/// Generates a random value between +/- the specified magnitude
func noise(magnitude: Float) -> Float {
	return (Float(arc4random()) / Float(UINT32_MAX) * magnitude * 2) - magnitude
}

/// Create a square wave from three size waves: f(x) = sin(x) + sin(3x)/3 + sin(5x)/5
func generateSquareWave(
	frequency: Float,
	sampleRate: Float,
	duration: Float) -> [Float]
{
	// Total number of samples
	let numberOfSamples = Int(duration * sampleRate)
	
	// Angle change per sample
	let angleDelta = (frequency / sampleRate) * 2 * Float.pi
	
	let squareWave: [Float] = (0..<numberOfSamples).map { index in
		let indexFloat = Float(index)
		
		let value: Float =
			sin(angleDelta * indexFloat) +
			sin(angleDelta * indexFloat * 3) / 3 +
			sin(angleDelta * indexFloat * 5) / 5
		
		
		return value + noise(magnitude: 0.15)
	}
	
	return squareWave
}

/// Caculates the linear autocorrelation of a 2-D signal
func calculateLinearAutocorrelation(
	ofInput input: UnsafeMutablePointer<Float>,
	count: Int) -> [Float]
{
	// log2(W), where W is the number of samples in the calculation window
	let log2n = UInt(floor(log2(Double(count))))
	
	// Largest power of 2 that is less than W. The FFT is more performant when applied to windows with lengths equal to powers of 2.
	let nPowerOfTwo = Int(1 << log2n)
	
	// Dividing the largest power of 2 by 2. Once we get into computations on complex buffers it will make sense why this value is important.
	let nOver2 = nPowerOfTwo / 2
	
	// The Fast Fourier Transform results in complex values, z = x + iy, where z is a complex number, x and y are the real it’s real and imaginary components respectively, and i = sqrt(-1). For this implementation, we must create separate buffers for the real x and imaginary y components.
	var real = [Float](repeating: 0, count: nOver2)
	var imag = [Float](repeating: 0, count: nOver2)
	
	// Since accelerates digital signal processing method to scale a signal is not in place, we must create output buffers for the result of a scaling operation that we will perform
	var scaledReal = [Float](repeating: 0, count: nOver2)
	var scaledImag = [Float](repeating: 0, count: nOver2)
	
	// A split complex buffer for storing real and imaginary components of complex numbers in the separate buffers defined above
	var tempSplitComplex = DSPSplitComplex(
		realp: &real,
		imagp: &imag)
	
	//Here we define fftSetup, or precalculated data that is used by Accelerate to perform Fast Fourier Transforms. The parameters are the log of the max input size the setup can handle and the types of sizes the setup is compatible with respectively. In this case kFFTRadix2 denotes that our input’s size will be a power of 2.
	guard
		let fftSetup = vDSP_create_fftsetup(log2n, Int32(kFFTRadix2))
	else {
		return []
	}
	
	//In order to put our input data into a split complex buffer, we must first rebound the memory such that we can temporarily treat it as if it were of type [DSPComplex] instead of type [Float], where a DSPComplex is 2 adjacent floating point values that make up a single complex number, with the first value being the real component and the second value being the imaginary component. Since this structure deals with pairs of floating values, we must stride through it by 2. A confusing point for me was why are we switching to a data structure that puts every other element of our entirely real signal into the imagery component of a DSPComplex. Essentially, Accelerate favors packing data in such a way that speeds up the FFT and preserves buffer size even if it doesn't make physical sense.
	input.withMemoryRebound(to: DSPComplex.self, capacity: nOver2) {
		//Once our data is cast as an array of DSPComplex, we use the Accelerate function vDSP_ctoz() to convert our data from the interleaved complex form to the split complex form, DSPSplitComplex, that the FFT function expects as an input. In the DSPSplitComplex form imaginary and real components of complex numbers are stored in separate buffers.
		vDSP_ctoz(
			$0, 2, // Input DSPComplex buffer
			&tempSplitComplex, 1, // Output DSPSplitComplex buffer
			vDSP_Length(nOver2)) // Number of "complex values" in our buffers
    }
	
	// We will use the in place variation of Accelerate's FFT. The transform is packed, meaning that all FFT results after the frequency W/2 are discarded and the real component of the DSPSplitComplex at the would be index (W/2) + 1 is stored in the imaginary component of the DSPSplitComplex at index 0. This enables the input and output buffers to be the same size, W/2, and due to the mirrored nature of FFT results, no non-recoverable data is lost. Note that Accelerate's IFFT is implemented in such a way that it unpacks the signal in addition to transforming it back to the time domain. For more information you can check out the Packing For One Dimensional Arrays section in Apple's Using Fourier Transforms documentation: https://developer.apple.com/library/archive/documentation/Performance/Conceptual/vDSP_Programming_Guide/UsingFourierTransforms/UsingFourierTransforms.html
	vDSP_fft_zrip(
		fftSetup, // Precalculated data
		&tempSplitComplex, 1, // Output/input buffer and stride
		log2n, // Log 2 of the input signal count
		FFTDirection(FFT_FORWARD)) // FFT direction
	
	//A thing to watch out for is that Accelerate's FFT functions do not perform any scaling automatically. The forward FFT requires us to scale the result by 1/2
	var scale: Float = 2
	
	//Here we use the vDSP_vsdiv() function, which divides a vector by a scaler, to scale our FFT result. Since it is not an in place function, we will utilize the scaled result buffers we created as part of step 1.
	vDSP_vsdiv(
		&real, 1, &scale, // Unscaled real component input buffer
		&scaledReal, 1, // Scaled real component output buffer
		vDSP_Length(nOver2))
	
	vDSP_vsdiv(
		&imag, 1, &scale, // Unscaled imaginary component input buffer
		&scaledImag, 1, // Scaled imaginary component output buffer
		vDSP_Length(nOver2))
	
	//Setting the split complex buffer to the new scaled values
	tempSplitComplex = DSPSplitComplex(
		realp: &scaledReal,
		imagp: &scaledImag)
	
	//This may look a little strange since we use the same argument three times in a row, so I'll break down what is happening. The first argument pair is the scaled FFT result from our last step and its stride. The first argument pair is multiplied by complex conjugate of the second argument pair. Since we want to multiply our signal by its own complex conjugate, the second argument pair is the same as the first. Lastly, we want to perform an in place operation, so the third argument pair, the output buffer, is yet again the same as the first and second.
	vDSP_zvcmul(
		&tempSplitComplex, 1, // Normal input
		&tempSplitComplex, 1, // Complex conjugate input
		&tempSplitComplex, 1, // Output = dot product of the two inputs
		vDSP_Length(nOver2))
	
	// Performing the IFFT. An important thing to note is that this signal reverses the packing process of the Accelerate's FFT. So no further unpacking action is required of us.
	vDSP_fft_zrip(
		fftSetup, // Precalculated data
		&tempSplitComplex, 1,  // Output/input buffer and stride
		log2n, // Log 2 of the input signal count
		FFTDirection(FFT_INVERSE)) // FFT direction
	
	// Before returning from the function, we destroy our precalculated data. If this is an operation you plan on performing many times, it may be better to store the precalculated data for future use.
	vDSP_destroy_fftsetup(fftSetup)
	
	//A convenient initializer for creating an array from a [DSPSplitComplex]. It even handles scaling. In this case we will scale by 1/W since that is the scaling that needs to be after the IFFT.
	return Array(
		fromSplitComplex: tempSplitComplex,
		scale: 1 / Float(nPowerOfTwo), // Dividing by window size to scale for IFFT
		count: nOver2)
}

// Samples per second of our input signal
let sampleRate: Float = 1024

// Generating the square wave that we will perform the autocorrelation on
var squareWave = generateSquareWave(frequency: 5, sampleRate: sampleRate, duration: 1)

let unpaddedCount = squareWave.count

// Padding our squre wave with 0's until it is twice the original size. This prevents artifacts in the autocorrelation calculation
squareWave.append(
	contentsOf: Array(repeating: 0, count: unpaddedCount)
)

// Calculating the linear autocorrelation of the square wave
let linearAC = calculateLinearAutocorrelation(
	ofInput: &squareWave,
	count: squareWave.count)

let sampleRateAsDouble = Double(sampleRate)

// Converting our orignal signal into plottable data entries
let originalDataEntries = squareWave[0..<unpaddedCount]
	.enumerated()
	.map { (index, value) in
		
	ChartDataEntry(
		x: Double(index) / sampleRateAsDouble, // Converting samples to seconds
		y: Double(value))
}

// Converting our autocorrelation result into plottable data entries
let linearACEntries = linearAC[0..<unpaddedCount]
	.enumerated()
	.map { (index, value) in
		
	ChartDataEntry(
		x: Double(index) / sampleRateAsDouble, // Converting samples to seconds
		y: Double(value / linearAC[0])) // Scaling by the max autocorrelation value
}

// Creating the original signal data set and defining its plot appearence properties
let originalDataSet = LineChartDataSet(
	entries: originalDataEntries,
	label: "Original Signal")

originalDataSet.setColor(.white)
originalDataSet.drawCirclesEnabled = false
originalDataSet.lineWidth = 1

// Creating the autocorrelation data set and defining its plot appearence properties
let linearACDataSet = LineChartDataSet(
	entries: linearACEntries,
	label: "Linear Autocorrelation")

linearACDataSet.setColor(.red)
linearACDataSet.drawCirclesEnabled = false
linearACDataSet.lineWidth = 2

// Adding both the original and autocorrelation data sets to the LineChartView
let chartData = LineChartData()
chartData.addDataSet(originalDataSet)
chartData.addDataSet(linearACDataSet)

// Displaying the LineChartView
let chartView = LineChartView(frame: CGRect(x: 10, y: 10, width: 400, height: 250))
chartView.data = chartData
chartView.xAxis.labelTextColor = .white
chartView.leftAxis.labelTextColor = .white
chartView.rightAxis.labelTextColor = .white
chartView.legend.textColor = .white
chartView.highlightPerTapEnabled = false

PlaygroundPage.current.liveView = chartView
