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
	//MARK: YOUR CODE GOES HERE
	
	return Array(repeating: 0, count: count)
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

