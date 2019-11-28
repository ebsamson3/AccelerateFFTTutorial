# AccelerateFFTTutorial
Supporting materials for a Swift tutorial on performing Fast Fourier Transforms using Apple's Accelerate Framework. The tutorial can be found [here](http://edwardsamson.com/using-a-swift-accelerate-implementation-of-the-fast-fourier-transform-to-calculate-linear-autocorrelation/)

## Usage

To use simply download/clone the repository, open AccelerateFFT.xcworkspace, and build the project so that the playgrounds have access to the included Charts module. 

In the workspace you will find the following playgrounds:

- **AccelerateFFT_Starter.playground:** Use this to follow along with the tutorial
- **AccelerateFFT.playground:** The end result of the tutorial
- **PitchDetection.playground:** A pitch detection algorithm that applies the tutorial's linear autocorrelation function. It is a Swift implementation of the methods described in the the article [A Smarter Way to Find Pitch](https://www.researchgate.net/publication/230554927_A_smarter_way_to_find_pitch) by Philip McLeod and Geoff Wyvill. While it works in the example case provided, I haven't rigorously tested it. 
