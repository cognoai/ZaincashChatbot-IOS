
Pod::Spec.new do |spec|

  spec.name         = "ZaincashChatbot-IOS-Cogno"
  spec.version      = "1.0.7"
  spec.summary      = "Simple chatbot SDK"
  spec.description  = "Chatbot SDK/ Framework ready to available with all types of iOS applications"
  spec.homepage     = "https://github.com/cognoai/ZaincashChatbot-IOS.git"

  spec.license      = "MIT"

  spec.author = { "Viraj Gund" => "viraj.gund@exotel.com" }

  spec.platform     = :ios, "11.0"

  spec.swift_version = '5.0'

  spec.source = { :git => "https://github.com/cognoai/ZaincashChatbot-IOS.git", :tag => "1.0.7" }

  spec.source_files  = 'ZaincashChatbot-IOS/**/*.swift'

  spec.framework  = "UIKit"

end
