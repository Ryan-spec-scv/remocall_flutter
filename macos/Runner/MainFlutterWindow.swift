import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  // 모바일 화면 비율 (일반적인 스마트폰 비율)
  let mobileAspectRatio: CGFloat = 9.0 / 16.0  // 세로/가로 비율 (16:9 세로모드)
  let defaultWidth: CGFloat = 390  // iPhone 14 기준 너비
  let defaultHeight: CGFloat = 844  // iPhone 14 기준 높이
  
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController
    
    // 초기 창 크기 설정
    let initialFrame = NSRect(x: 100, y: 100, width: defaultWidth, height: defaultHeight)
    self.setFrame(initialFrame, display: true)
    
    // 창 스타일 설정
    self.titlebarAppearsTransparent = false
    self.title = "SnapPay"
    self.isMovableByWindowBackground = true
    
    // 최소/최대 크기 설정
    self.minSize = NSSize(width: 320, height: 320 / mobileAspectRatio)
    self.maxSize = NSSize(width: 500, height: 500 / mobileAspectRatio)
    
    // 크기 조정 시 비율 유지를 위한 델리게이트 설정
    self.delegate = self
    
    // 창을 화면 중앙에 배치
    self.center()
    
    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}

// NSWindowDelegate 구현으로 비율 유지
extension MainFlutterWindow: NSWindowDelegate {
  func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
    // 현재 크기
    let currentAspectRatio = frameSize.width / frameSize.height
    
    // 목표 비율과의 차이 계산
    let targetAspectRatio = mobileAspectRatio
    
    var newSize = frameSize
    
    // 비율 조정 - 너비 기준으로 높이 계산
    if abs(currentAspectRatio - targetAspectRatio) > 0.01 {
      // 너비를 기준으로 높이 계산
      newSize.height = frameSize.width / targetAspectRatio
      
      // 최대/최소 크기 제한 확인
      if newSize.height > maxSize.height {
        newSize.height = maxSize.height
        newSize.width = newSize.height * targetAspectRatio
      } else if newSize.height < minSize.height {
        newSize.height = minSize.height
        newSize.width = newSize.height * targetAspectRatio
      }
    }
    
    return newSize
  }
  
  func windowDidResize(_ notification: Notification) {
    // 크기 조정 후 추가 처리가 필요한 경우 여기에 구현
  }
}
