//
//  DemoFramework.swift
//  DemoFramework
//
//  Created by sangam pokharel on 15/07/2025.
//

import Foundation
import UIKit
import SwiftUI

// MARK: - Public Types

public enum PaymentStatus {
    case success
    case failed
    case cancelled
}

public struct PaymentInfo {
    public let transactionId: String
    public let amount: Double
    public let itemDescription: String
    public let merchantName: String
    
    public init(amount: Double, itemDescription: String, merchantName: String) {
        self.transactionId = UUID().uuidString
        self.amount = amount
        self.itemDescription = itemDescription
        self.merchantName = merchantName
    }
}

public struct PaymentResult {
    public let transactionId: String
    public let status: PaymentStatus
    public let amount: Double
    public let timestamp: Date
    public let message: String
    
    public init(transactionId: String, status: PaymentStatus, amount: Double, timestamp: Date = Date(), message: String) {
        self.transactionId = transactionId
        self.status = status
        self.amount = amount
        self.timestamp = timestamp
        self.message = message
    }
}

// MARK: - Main Framework Class (renamed to avoid conflict)

public final class PaymentFramework {
    public init() {}
    
    /// Initiates payment using the PaymentSDK
    /// - Parameters:
    ///   - paymentInfo: Payment information
    ///   - completion: Callback with payment result
    public func initiatePayment(paymentInfo: PaymentInfo, completion: @escaping (PaymentResult) -> Void) {
        PaymentSDK.shared.initiatePayment(paymentInfo: paymentInfo, completion: completion)
    }
    
    /// Convenience method for payment initiation
    /// - Parameters:
    ///   - amount: Payment amount
    ///   - description: Item description
    ///   - merchantName: Merchant name
    ///   - completion: Callback with payment result
    public func initiatePayment(amount: Double, description: String, merchantName: String, completion: @escaping (PaymentResult) -> Void) {
        let paymentInfo = PaymentInfo(amount: amount, itemDescription: description, merchantName: merchantName)
        PaymentSDK.shared.initiatePayment(paymentInfo: paymentInfo, completion: completion)
    }
}

// MARK: - PaymentSDK

public final class PaymentSDK {
    public static let shared = PaymentSDK()
    
    private var activeCoordinators: [String: PaymentCoordinator] = [:]
    
    private init() {}
    
    /// Initiates payment process with given payment information
    /// - Parameters:
    ///   - paymentInfo: Payment details including amount, description, and merchant name
    ///   - completion: Callback with payment result
    public func initiatePayment(paymentInfo: PaymentInfo, completion: @escaping (PaymentResult) -> Void) {
        let coordinator = PaymentCoordinator(paymentInfo: paymentInfo) { [weak self] result in
            // Remove coordinator from active coordinators when payment is complete
            self?.activeCoordinators.removeValue(forKey: paymentInfo.transactionId)
            completion(result)
        }
        
        // Store coordinator to keep it alive during payment process
        activeCoordinators[paymentInfo.transactionId] = coordinator
        coordinator.start()
    }
    
    /// Convenience method for quick payment initiation
    /// - Parameters:
    ///   - amount: Payment amount
    ///   - description: Item description
    ///   - merchantName: Merchant name
    ///   - completion: Callback with payment result
    public func initiatePayment(amount: Double, description: String, merchantName: String, completion: @escaping (PaymentResult) -> Void) {
        let paymentInfo = PaymentInfo(amount: amount, itemDescription: description, merchantName: merchantName)
        initiatePayment(paymentInfo: paymentInfo, completion: completion)
    }
}

// MARK: - SystemOverlayManager

public class SystemOverlayManager {
    private var overlayWindow: UIWindow?
    private static let shared = SystemOverlayManager()
    
    public static func showPaymentSuccessOverlay(result: PaymentResult) {
        shared.showOverlay(result: result)
    }
    
    private func showOverlay(result: PaymentResult) {
        DispatchQueue.main.async {
            self.createOverlayWindow(result: result)
        }
    }
    
    private func createOverlayWindow(result: PaymentResult) {
        // Create overlay window
        let windowScene = UIApplication.shared.connectedScenes
            .filter { $0.activationState == .foregroundActive }
            .first as? UIWindowScene
        
        guard let windowScene = windowScene else { return }
        
        overlayWindow = UIWindow(windowScene: windowScene)
        overlayWindow?.windowLevel = UIWindow.Level.alert + 1
        overlayWindow?.backgroundColor = UIColor.clear
        overlayWindow?.isHidden = false
        
        // Create SwiftUI overlay view
        let overlayView = SystemOverlayView(result: result) { [weak self] in
            self?.dismissOverlay()
        }
        
        let hostingController = UIHostingController(rootView: overlayView)
        hostingController.view.backgroundColor = UIColor.clear
        
        overlayWindow?.rootViewController = hostingController
        overlayWindow?.makeKeyAndVisible()
        
        // Auto dismiss after 8 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 8.0) {
            self.dismissOverlay()
        }
    }
    
    private func dismissOverlay() {
        DispatchQueue.main.async {
            self.overlayWindow?.isHidden = true
            self.overlayWindow = nil
        }
    }
}

// MARK: - Internal Implementation

internal struct SystemOverlayView: View {
    let result: PaymentResult
    let onDismiss: () -> Void
    
    @State private var showOverlay = false
    @State private var dragOffset: CGSize = .zero
    
    var body: some View {
        GeometryReader { geometry in
            VStack {
                // Top overlay banner (similar to incoming call style)
                HStack {
                    // Payment icon
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                        .padding(.leading, 16)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Payment Successful")
                            .font(.headline)
                            .foregroundColor(.white)
                            .fontWeight(.semibold)
                        
                        Text("\(String(format: "$%.2f", result.amount)) • \(result.transactionId)")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.9))
                    }
                    
                    Spacer()
                    
                    // Close button
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(.trailing, 16)
                }
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.green, Color.green.opacity(0.8)]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                .offset(y: showOverlay ? 0 : -100)
                .offset(dragOffset)
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: showOverlay)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if value.translation.height < 0 {
                                dragOffset = value.translation
                            }
                        }
                        .onEnded { value in
                            if value.translation.height < -50 {
                                onDismiss()
                            } else {
                                dragOffset = .zero
                            }
                        }
                )
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 50) // Account for status bar
        }
        .onAppear {
            showOverlay = true
        }
    }
}

internal class PaymentCoordinator {
    private var presentingViewController: UIViewController?
    private let paymentInfo: PaymentInfo
    private let completion: (PaymentResult) -> Void
    
    init(paymentInfo: PaymentInfo, completion: @escaping (PaymentResult) -> Void) {
        self.paymentInfo = paymentInfo
        self.completion = completion
    }
    
    func start() {
        DispatchQueue.main.async {
            self.presentPaymentScreen()
        }
    }
    
    private func presentPaymentScreen() {
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
              let window = windowScene.windows.first(where: { $0.isKeyWindow }) else {
            handlePaymentResult(.init(transactionId: paymentInfo.transactionId, status: .failed, amount: paymentInfo.amount, message: "Failed to get window"))
            return
        }
        
        // Find the topmost presented view controller
        var topController = window.rootViewController
        while let presentedController = topController?.presentedViewController {
            topController = presentedController
        }
        
        guard let rootViewController = topController else {
            handlePaymentResult(.init(transactionId: paymentInfo.transactionId, status: .failed, amount: paymentInfo.amount, message: "Failed to get root view controller"))
            return
        }
        
        // Check if we can present
        if rootViewController.presentedViewController != nil {
            // If already presenting, wait a bit and try again
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.presentPaymentScreen()
            }
            return
        }
        
        let paymentSummaryView = PaymentSummaryView(
            paymentInfo: paymentInfo,
            onPaymentConfirm: { [weak self] in
                print("Payment confirm button tapped") // Debug log
                self?.showPaymentProcessing()
            },
            onCancel: { [weak self] in
                print("Payment cancel button tapped") // Debug log
                self?.handlePaymentResult(.init(transactionId: self?.paymentInfo.transactionId ?? "", status: .cancelled, amount: self?.paymentInfo.amount ?? 0, message: "Payment cancelled by user"))
            }
        )
        
        let hostingController = UIHostingController(rootView: paymentSummaryView)
        hostingController.modalPresentationStyle = .pageSheet
        hostingController.modalTransitionStyle = .coverVertical
        
        // Configure sheet presentation
        if let sheet = hostingController.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
        
        self.presentingViewController = hostingController
        rootViewController.present(hostingController, animated: true)
    }
    
    private func showPaymentProcessing() {
        print("Starting payment processing") // Debug log
        
        // Show loading state first
        let loadingView = PaymentProcessingView(
            paymentInfo: paymentInfo,
            onComplete: { [weak self] in
                self?.showPaymentSuccess()
            }
        )
        
        let hostingController = UIHostingController(rootView: loadingView)
        hostingController.modalPresentationStyle = .overFullScreen
        hostingController.modalTransitionStyle = .crossDissolve
        
        self.presentingViewController?.present(hostingController, animated: true)
    }
    
    private func showPaymentSuccess() {
        print("Showing payment success") // Debug log
        
        // Simulate payment processing delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            let paymentResult = PaymentResult(
                transactionId: self.paymentInfo.transactionId,
                status: .success,
                amount: self.paymentInfo.amount,
                message: "Payment completed successfully"
            )
            
            let paymentSuccessView = PaymentSuccessView(
                paymentResult: paymentResult,
                onDone: { [weak self] in
                    print("Payment success done button tapped") // Debug log
                    self?.handlePaymentResult(paymentResult)
                }
            )
            
            let hostingController = UIHostingController(rootView: paymentSuccessView)
            hostingController.modalPresentationStyle = .overFullScreen
            hostingController.modalTransitionStyle = .crossDissolve
            
            // Dismiss processing view first, then show success
            self.presentingViewController?.presentedViewController?.dismiss(animated: true) {
                self.presentingViewController?.present(hostingController, animated: true)
            }
        }
    }
    
    private func handlePaymentResult(_ result: PaymentResult) {
        print("Handling payment result: \(result.status)") // Debug log
        
        DispatchQueue.main.async {
            // First dismiss all payment screens
            let controllerToDismiss = self.presentingViewController
            
            // If we have a success view presented on top, dismiss it first
            if let successController = controllerToDismiss?.presentedViewController {
                successController.dismiss(animated: true) {
                    // Then dismiss the payment summary view
                    controllerToDismiss?.dismiss(animated: true) {
                        self.showSystemOverlayAndComplete(result: result)
                    }
                }
            } else {
                // Just dismiss the payment summary view
                controllerToDismiss?.dismiss(animated: true) {
                    self.showSystemOverlayAndComplete(result: result)
                }
            }
        }
    }
    
    private func showSystemOverlayAndComplete(result: PaymentResult) {
        // Show system overlay for success
        if result.status == .success {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                SystemOverlayManager.showPaymentSuccessOverlay(result: result)
            }
        }
        
        // Call completion handler
        self.completion(result)
    }
}

internal struct PaymentSummaryView: View {
    let paymentInfo: PaymentInfo
    let onPaymentConfirm: () -> Void
    let onCancel: () -> Void
    
    @State private var isProcessing = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "creditcard.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        
                        Text("Payment Summary")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("Please review your payment details")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 20)
                    
                    // Payment Details Card
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Payment Details")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        VStack(spacing: 12) {
                            PaymentDetailRow(title: "Transaction ID", value: paymentInfo.transactionId)
                            PaymentDetailRow(title: "Amount", value: String(format: "$%.2f", paymentInfo.amount))
                            PaymentDetailRow(title: "Description", value: paymentInfo.itemDescription)
                            PaymentDetailRow(title: "Merchant", value: paymentInfo.merchantName)
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    
                    // Security Info
                    VStack(spacing: 8) {
                        HStack {
                            Image(systemName: "lock.shield.fill")
                                .foregroundColor(.green)
                            Text("Secure Payment")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Spacer()
                        }
                        
                        Text("Your payment information is encrypted and secure")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(12)
                    
                    Spacer()
                    
                    // Action Buttons
                    VStack(spacing: 12) {
                        Button(action: {
                            print("Confirm button pressed") // Debug log
                            isProcessing = true
                            onPaymentConfirm()
                        }) {
                            HStack {
                                if isProcessing {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "creditcard")
                                }
                                Text(isProcessing ? "Processing..." : "Confirm Payment")
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(isProcessing ? Color.blue.opacity(0.7) : Color.blue)
                            .cornerRadius(12)
                        }
                        .disabled(isProcessing)
                        
                        Button(action: {
                            print("Cancel button pressed") // Debug log
                            onCancel()
                        }) {
                            Text("Cancel")
                                .fontWeight(.medium)
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(12)
                        }
                        .disabled(isProcessing)
                    }
                }
                .padding()
            }
            .navigationTitle("Payment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        onCancel()
                    }
                    .disabled(isProcessing)
                }
            }
        }
        .background(Color.black.opacity(0.3))
    }
}

internal struct PaymentDetailRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

internal struct PaymentSuccessView: View {
    let paymentResult: PaymentResult
    let onDone: () -> Void
    
    @State private var showCheckmark = false
    @State private var showContent = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Spacer()
                
                // Success Animation
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.1))
                        .frame(width: 120, height: 120)
                        .scaleEffect(showContent ? 1 : 0.5)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: showContent)
                    
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.green)
                        .scaleEffect(showCheckmark ? 1 : 0)
                        .animation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.2), value: showCheckmark)
                }
                
                // Success Message
                VStack(spacing: 16) {
                    Text("Payment Successful!")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .opacity(showContent ? 1 : 0)
                        .animation(.easeInOut.delay(0.4), value: showContent)
                    
                    Text("Your payment has been processed successfully")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .opacity(showContent ? 1 : 0)
                        .animation(.easeInOut.delay(0.6), value: showContent)
                }
                
                // Transaction Details
                VStack(alignment: .leading, spacing: 16) {
                    Text("Transaction Details")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    VStack(spacing: 12) {
                        TransactionDetailRow(title: "Transaction ID", value: paymentResult.transactionId)
                        TransactionDetailRow(title: "Amount", value: String(format: "$%.2f", paymentResult.amount))
                        TransactionDetailRow(title: "Status", value: statusText(paymentResult.status))
                        TransactionDetailRow(title: "Date", value: formatDate(paymentResult.timestamp))
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                .opacity(showContent ? 1 : 0)
                .animation(.easeInOut.delay(0.8), value: showContent)
                
                Spacer()
                
                // Action Button
                Button(action: onDone) {
                    HStack {
                        Image(systemName: "arrow.right.circle.fill")
                        Text("Done")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.green)
                    .cornerRadius(12)
                }
                .opacity(showContent ? 1 : 0)
                .animation(.easeInOut.delay(1.0), value: showContent)
            }
            .padding()
            .navigationTitle("Payment Complete")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarHidden(true)
        }
        .background(Color.black.opacity(0.3))
        .onAppear {
            showCheckmark = true
            showContent = true
        }
    }
    
    private func statusText(_ status: PaymentStatus) -> String {
        switch status {
        case .success: return "Success"
        case .failed: return "Failed"
        case .cancelled: return "Cancelled"
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

internal struct TransactionDetailRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

internal struct PaymentProcessingView: View {
    let paymentInfo: PaymentInfo
    let onComplete: () -> Void
    
    @State private var rotationAngle: Double = 0
    @State private var progress: Double = 0
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // Processing Animation
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .stroke(Color.blue.opacity(0.3), lineWidth: 6)
                        .frame(width: 80, height: 80)
                    
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(Color.blue, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(rotationAngle))
                        .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: rotationAngle)
                }
                
                Text("Processing Payment...")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text("Please wait while we process your payment")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Payment Info
            VStack(alignment: .leading, spacing: 12) {
                Text("Transaction Details")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                VStack(spacing: 8) {
                    PaymentDetailRow(title: "Amount", value: String(format: "$%.2f", paymentInfo.amount))
                    PaymentDetailRow(title: "Description", value: paymentInfo.itemDescription)
                    PaymentDetailRow(title: "Merchant", value: paymentInfo.merchantName)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
            
            Spacer()
        }
        .padding()
        .background(Color.black.opacity(0.3))
        .onAppear {
            startProcessingAnimation()
        }
    }
    
    private func startProcessingAnimation() {
        // Start rotation animation
        rotationAngle = 360
        
        // Simulate progress
        withAnimation(.easeInOut(duration: 2.0)) {
            progress = 1.0
        }
        
        // Complete after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            onComplete()
        }
    }
}