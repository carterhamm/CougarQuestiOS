//
//  Root.swift
//  CougarQuest
//
//  Created by Carter Hammond on 4/27/25.
//

import Foundation
import UIKit

extension UIApplication {
  static var rootViewController: UIViewController? {
    return UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }
      .first { $0.isKeyWindow }?
      .rootViewController
  }
}
