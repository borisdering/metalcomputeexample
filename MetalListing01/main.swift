//
//  main.swift
//  MetalListing01
//
//  Created by Boris Dering on 18.08.19.
//  Copyright © 2019 Boris Dering. All rights reserved.
//

import Foundation
import Metal

/// defines the lenght of the array which we need to add on
/// the gpu.
let lenght = 256

/// Generates and returns a buffer filled with an array of type float.
/// - Parameter buffer: Metal buffer.
func generateRandomFloatData(buffer: inout MTLBuffer) {
    
    let stride = MemoryLayout<Float>.stride
    let data = buffer.contents()
    
    for i in 0...buffer.length {
        let value = Float.random(in: 0...5)
        data.advanced(by: stride * i).storeBytes(of: Float(round(value * 1000) / 1000), as: Float.self)
    }
}

/// Verifies the result by comparing the first and second array with the result
/// buffer.
/// - Parameter b1: First buffer.
/// - Parameter b2: Second buffer.
/// - Parameter r: Result buffer where the added result is.
func verifyResult(b1: MTLBuffer, b2: MTLBuffer, r: MTLBuffer) {
    
    // handle result
    let a = convert(buffer: b1)
    let b = convert(buffer: b2)
    let result = convert(buffer: r)
    
    for i in 0...a.count - 1 {
        let assertion = result[i] == (a[i] + b[i])
        print("assertion at position \(i) is \(assertion), comparing \(result[i]) = \(a[i]) + \(b[i])")
        assert(assertion)
    }
}

/// Convertes a metal buffer to a float array.
/// - Parameter buffer: Buffer to convert to array.
func convert(buffer: MTLBuffer) -> [Float] {
    
    let contents = buffer.contents()
    let length = buffer.length
    
    let start = contents.bindMemory(to: Float.self, capacity: length)
    let buffer = UnsafeBufferPointer(start: start, count: length)
    return Array(buffer)
}

// define device and init default library to get
// access to the "add" shader function...
let device = MTLCreateSystemDefaultDevice()
guard let library = device?.makeDefaultLibrary() else { fatalError("could not init default library") }

// instatinate the add function by calling the library which
// we defined in schaders.metal file. 
guard let function = library.makeFunction(name: "add_arrays") else { fatalError("could not create add function") }

// prepare the compute pipeline
// do not panic, this instance is just a pipeline which holds
let pipeline = try! device!.makeComputePipelineState(function: function)

// create command queue so we can send any tasks to the GPU.
let commandQueue = device!.makeCommandQueue()

// create data buffers...
var firstBuffer = device!.makeBuffer(length: lenght, options: MTLResourceOptions.storageModeShared)!
var secondBuffer = device!.makeBuffer(length: lenght, options: MTLResourceOptions.storageModeShared)!
var resultBuffer = device!.makeBuffer(length: lenght, options: MTLResourceOptions.storageModeShared)!

// fill buffer with random data...
generateRandomFloatData(buffer: &firstBuffer)
generateRandomFloatData(buffer: &secondBuffer)

let commandBuffer = commandQueue!.makeCommandBuffer()!
// create compute encoder...
let computeEncoder = commandBuffer.makeComputeCommandEncoder()!

computeEncoder.setComputePipelineState(pipeline)
computeEncoder.setBuffer(firstBuffer, offset: 0, index: 0)
computeEncoder.setBuffer(secondBuffer, offset: 0, index: 1)
computeEncoder.setBuffer(resultBuffer, offset: 0, index: 2)

// define how many threads will be used to compute
// we need 1D size of threads to compute due to the lenght of the array
let gridSize = MTLSize(width: firstBuffer.length, height: 1, depth: 1)

// now lets see how many threads we got...
// if we have to many we may need to shrink the threads optionally
let threadGroupSize = MTLSize(
    width: (firstBuffer.length < pipeline.maxTotalThreadsPerThreadgroup) ? firstBuffer.length : pipeline.maxTotalThreadsPerThreadgroup,
    height: 1,
    depth: 1)

computeEncoder.dispatchThreads(gridSize, threadsPerThreadgroup: threadGroupSize)
computeEncoder.endEncoding()
commandBuffer.commit()
commandBuffer.waitUntilCompleted()

verifyResult(b1: firstBuffer, b2: secondBuffer, r: resultBuffer)
