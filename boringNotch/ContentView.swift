//
//  ContentView.swift
//  boringNotchApp
//
//  Created by Harsh Vardhan Goswami  on 02/08/24
//  Modified by Richard Kunkli on 24/08/2024.
//

import AVFoundation
import Combine
import KeyboardShortcuts
import SwiftUI

struct ContentView: View {
    let onHover: () -> Void
    
    @EnvironmentObject var vm: BoringViewModel
    @StateObject var batteryModel: BatteryStatusViewModel
    @EnvironmentObject var musicManager: MusicManager
    @StateObject var webcamManager: WebcamManager = .init()
    
    
    @State private var hoverStartTime: Date?
    @State private var hoverTimer: Timer?
    @State private var hoverAnimation: Bool = false
    
    @State private var gestureProgress: CGFloat = .zero
    
    @State private var haptics: Bool = false
    
    @Namespace var albumArtNamespace
    
    var body: some View {
        ZStack {
            NotchLayout()
                .padding(.horizontal, vm.notchState == .open ? vm.cornerRadiusScaling ? (vm.sizes.cornerRadius.opened.inset! - 5) : (vm.sizes.cornerRadius.closed.inset! - 5) : 12)
                .padding([.horizontal, .bottom], vm.notchState == .open ? 12 : 0)
                .frame(maxWidth: (((musicManager.isPlaying || !musicManager.isPlayerIdle) && vm.notchState == .closed && vm.showMusicLiveActivityOnClosed) || (vm.expandingView.show && (vm.expandingView.type == .battery)) || vm.inlineHUD) ? nil : vm.notchSize.width + ((hoverAnimation || (vm.notchState == .closed)) ? 20 : 0) + gestureProgress, maxHeight: ((vm.sneakPeak.show && vm.sneakPeak.type != .music) || (vm.sneakPeak.show && vm.sneakPeak.type == .music && vm.notchState == .closed)) ? nil : vm.notchSize.height + (hoverAnimation ? 8 : 0) + gestureProgress / 3, alignment: .top)
                .background(.black)
                .mask {
                    NotchShape(cornerRadius: ((vm.notchState == .open) && vm.cornerRadiusScaling) ? vm.sizes.cornerRadius.opened.inset : vm.sizes.cornerRadius.closed.inset)
                }
                .frame(width: vm.notchState == .closed ? (((musicManager.isPlaying || !musicManager.isPlayerIdle) && vm.showMusicLiveActivityOnClosed) || (vm.expandingView.show && (vm.expandingView.type == .battery)) || (vm.inlineHUD && vm.sneakPeak.show && vm.sneakPeak.type != .music)) ? nil : Sizes().size.closed.width! + (hoverAnimation ? 20 : 0) + gestureProgress : nil, height: vm.notchState == .closed ? Sizes().size.closed.height! + (hoverAnimation ? 8 : 0) + gestureProgress / 3 : nil, alignment: .top)
                .conditionalModifier(vm.openNotchOnHover) { view in
                    view
                        .onHover { hovering in
                            if hovering {
                                withAnimation(.bouncy) {
                                    hoverAnimation = true
                                }
                                
                                if (vm.notchState == .closed) && vm.enableHaptics {
                                    haptics.toggle()
                                }
                                
                                if vm.sneakPeak.show {
                                    return
                                }
                                
                                startHoverTimer()
                            } else {
                                withAnimation(.bouncy) {
                                    hoverAnimation = false
                                }
                                cancelHoverTimer()
                                
                                if vm.notchState == .open {
                                    vm.close()
                                }
                            }
                        }
                }
                .conditionalModifier(!vm.openNotchOnHover) { view in
                    view
                        .onHover { hovering in
                            if hovering {
                                withAnimation(vm.animation) {
                                    hoverAnimation = true
                                }
                            } else {
                                withAnimation(vm.animation) {
                                    hoverAnimation = false
                                }
                                if vm.notchState == .open {
                                    vm.close()
                                }
                            }
                        }
                        .onTapGesture {
                            if (vm.notchState == .closed) && vm.enableHaptics {
                                haptics.toggle()
                            }
                            doOpen()
                        }
                        .conditionalModifier(vm.enableGestures) { view in
                            view
                                .panGesture(direction: .down) { translation, phase in
                                    if vm.notchState == .closed {
                                        withAnimation(.smooth) {
                                            gestureProgress = (translation / vm.gestureSensitivity) * 20
                                        }
                                        
                                        if phase == .ended {
                                            withAnimation(.smooth) {
                                                gestureProgress = .zero
                                            }
                                        }
                                    }
                                    if translation > vm.gestureSensitivity {
                                        if (vm.notchState == .closed) && vm.enableHaptics {
                                            haptics.toggle()
                                        }
                                        withAnimation(.smooth) {
                                            gestureProgress = .zero
                                        }
                                        doOpen()
                                    }
                                }
                        }
                }
                .conditionalModifier(vm.closeGestureEnabled && vm.enableGestures) { view in
                    view
                        .panGesture(direction: .up) { translation, phase in
                            if vm.notchState == .open {
                                withAnimation(.smooth) {
                                    gestureProgress = (translation / vm.gestureSensitivity) * -20
                                }
                                if phase == .ended {
                                    withAnimation(.smooth) {
                                        gestureProgress = .zero
                                    }
                                }
                                if translation > vm.gestureSensitivity {
                                    withAnimation(.smooth) {
                                        gestureProgress = .zero
                                        hoverAnimation = false
                                    }
                                    vm.close()
                                    if (vm.notchState == .closed) && vm.enableHaptics {
                                        haptics.toggle()
                                    }
                                }
                            }
                        }
                }
                .onAppear(perform: {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        withAnimation(vm.animation) {
                            if vm.firstLaunch {
                                doOpen()
                            }
                        }
                    }
                })
                .background(dragDetector)
                .sensoryFeedback(.alignment, trigger: haptics)
                .contextMenu {
                    SettingsLink(label: {
                        Text("Settings")
                    })
                    .keyboardShortcut(KeyEquivalent(","), modifiers: .command)
                    Button("Edit") {
                        let dn = DynamicNotch(content: EditPanelView())
                        dn.toggle()
                    }
#if DEBUG
                    .disabled(false)
#else
                    .disabled(true)
#endif
                    .keyboardShortcut("E", modifiers: .command)
                }
        }
        .frame(maxWidth: Sizes().size.opened.width! + 40, maxHeight: Sizes().size.opened.height! + 20, alignment: .top)
        .shadow(color: ((vm.notchState == .open || hoverAnimation) && vm.enableShadow) ? .black.opacity(0.6) : .clear, radius: vm.cornerRadiusScaling ? 10 : 5)
        .environmentObject(vm)
        .environmentObject(batteryModel)
        .environmentObject(musicManager)
        .environmentObject(webcamManager)
    }
    
    @ViewBuilder
    func NotchLayout() -> some View {
        VStack(alignment: .leading) {
            VStack(alignment: .leading) {
                if vm.firstLaunch {
                    Spacer()
                    HelloAnimation().frame(width: 200, height: 80).onAppear(perform: {
                        vm.closeHello()
                    })
                    .padding(.top, 40)
                    Spacer()
                } else {
                    if vm.expandingView.type == .battery && vm.expandingView.show && vm.notchState == .closed {
                        HStack(spacing: 0) {
                            HStack {
                                Text("Charging")
                                    .font(.subheadline)
                            }
                            
                            Rectangle()
                                .fill(.black)
                                .frame(width: vm.sizes.size.closed.width! + 5)
                            
                            HStack {
                                BoringBatteryView(
                                    batteryPercentage: batteryModel.batteryPercentage, isPluggedIn: batteryModel.isPluggedIn,
                                    batteryWidth: 30
                                )
                            }
                            .frame(width: 70, alignment: .trailing)
                        }
                        .frame(height: Sizes().size.closed.height! + (hoverAnimation ? 8 : 0), alignment: .center)
                    } else if vm.sneakPeak.show && vm.inlineHUD && (vm.sneakPeak.type != .music) && (vm.sneakPeak.type != .battery) {
                        InlineHUD(type: $vm.sneakPeak.type, value: $vm.sneakPeak.value, hoverAnimation: $hoverAnimation, gestureProgress: $gestureProgress)
                            .transition(.opacity)
                    } else if !vm.expandingView.show && vm.notchState == .closed && (musicManager.isPlaying || !musicManager.isPlayerIdle) && vm.showMusicLiveActivityOnClosed {
                        MusicLiveActivity()
                    } else {
                        BoringHeader()
                            .frame(height: Sizes().size.closed.height!)
                    }
                    
                    if vm.sneakPeak.show && !vm.inlineHUD {
                        if (vm.sneakPeak.type != .music) && (vm.sneakPeak.type != .battery) {
                            SystemEventIndicatorModifier(eventType: $vm.sneakPeak.type, value: $vm.sneakPeak.value, sendEventBack: { _ in
                                //
                            })
                            .padding(.bottom, 10)
                            .padding(.leading, 4)
                            .padding(.trailing, 8)
                        } else if vm.sneakPeak.type != .battery {
                            if vm.notchState == .closed {
                                HStack(alignment: .center) {
                                    Image(systemName: "music.note")
                                    GeometryReader { geo in
                                        MarqueeText(musicManager.songTitle + " - " + musicManager.artistName, textColor: .gray, minDuration: 1, frameWidth: geo.size.width)
                                    }
                                }
                                .foregroundStyle(.gray)
                                .padding(.bottom, 10)
                            }
                        }
                    }
                }
            }
            .conditionalModifier((vm.sneakPeak.show && (vm.sneakPeak.type == .music) && vm.notchState == .closed) || (vm.sneakPeak.show && (vm.sneakPeak.type != .music) && (musicManager.isPlaying || !musicManager.isPlayerIdle))) { view in
                view
                    .fixedSize()
            }
            
            ZStack {
                if vm.notchState == .open {
                    switch vm.currentView {
                        case .home:
                            NotchHomeView(albumArtNamespace: albumArtNamespace)
                        case .shelf:
                            NotchShelfView()
                    }
                }
            }
            .allowsHitTesting(vm.notchState == .open)
        }
    }
    
    @ViewBuilder
    func MusicLiveActivity() -> some View {
        HStack {
            HStack {
                Color.clear
                    .aspectRatio(1, contentMode: .fit)
                    .background(
                        Image(nsImage: musicManager.albumArt)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    )
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: vm.musicPlayerSizes.image.cornerRadius.closed.inset!))
                    .matchedGeometryEffect(id: "albumArt", in: albumArtNamespace)
                    .frame(width: vm.sizes.size.closed.height! - 12, height: vm.sizes.size.closed.height! - 12)
            }
            .frame(width: vm.sizes.size.closed.height! - (hoverAnimation ? 0 : 12) + gestureProgress / 2, height: vm.sizes.size.closed.height! - (hoverAnimation ? 0 : 12))
            
            Rectangle()
                .fill(.black)
                .frame(width: vm.sizes.size.closed.width! - 20)
            
            HStack {
                Rectangle()
                    .fill(Color(nsColor: musicManager.avgColor).gradient)
                    .mask {
                        AudioSpectrumView(
                            isPlaying: $musicManager.isPlaying
                        )
                        .frame(width: 16, height: 12)
                    }
            }
            .frame(width: vm.sizes.size.closed.height! - (hoverAnimation ? 0 : 12) + gestureProgress / 2, height: vm.sizes.size.closed.height! - (hoverAnimation ? 0 : 12), alignment: .center)
        }
        .frame(height: Sizes().size.closed.height! + (hoverAnimation ? 8 : 0), alignment: .center)
    }
    
    @ViewBuilder
    var dragDetector: some View {
        if vm.boringShelf {
            Rectangle()
                .fill(.clear)
                .contentShape(Rectangle())
                .onDrop(of: [.data], isTargeted: $vm.dragDetectorTargeting) { _ in true }
                .onChange(of: vm.anyDropZoneTargeting) { _, isTargeted in
                    if isTargeted, vm.notchState == .closed {
                        vm.currentView = .shelf
                        doOpen()
                    } else if !isTargeted {
                        print("DROP EVENT", vm.dropEvent)
                        if vm.dropEvent {
                            vm.dropEvent = false
                            return
                        }
                        
                        vm.dropEvent = false
                        vm.close()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        } else {
            EmptyView()
        }
    }
    
    private func startHoverTimer() {
        hoverStartTime = Date()
        hoverTimer?.invalidate()
        withAnimation(vm.animation) {
            hoverAnimation = true
        }
        hoverTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            checkHoverDuration()
        }
    }
    
    private func doOpen() {
        vm.open()
        cancelHoverTimer()
    }
    
    private func checkHoverDuration() {
        guard let startTime = hoverStartTime else { return }
        let hoverDuration = Date().timeIntervalSince(startTime)
        if hoverDuration >= vm.minimumHoverDuration {
            doOpen()
        }
    }
    
    private func cancelHoverTimer() {
        hoverTimer?.invalidate()
        hoverTimer = nil
        hoverStartTime = nil
        withAnimation(vm.animation) {
            hoverAnimation = false
        }
    }
}
