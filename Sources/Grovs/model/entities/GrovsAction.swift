//
//  Action.swift
//
//  grovs
//


import Foundation

/// A class that represents an executable action with success and failure handling.
class GrovsAction {

    /// The block to execute when the action is triggered.
    let mainBlock: GrovsEmptyClosure

    /// The block to execute if the action needs to be marked as failed.
    let failureBlock: GrovsEmptyClosure

    /// Initializes an Action with an execution block and a failure block.
    /// - Parameters:
    ///   - execution: A closure representing the main action to perform.
    ///   - failure: A closure that handles errors if the execution fails.
    init(mainBlock: @escaping GrovsEmptyClosure, failureBlock: @escaping GrovsEmptyClosure) {
        self.mainBlock = mainBlock
        self.failureBlock = failureBlock
    }
}
