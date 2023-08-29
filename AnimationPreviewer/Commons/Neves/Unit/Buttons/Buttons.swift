//
//  Buttons.swift
//  Neves
//
//  Created by aa on 2022/3/28.
//

class CustomLayoutButton: UIButton {
    var layoutSubviewsHandler: ((CustomLayoutButton) -> ())?
    override func layoutSubviews() {
        super.layoutSubviews()
        layoutSubviewsHandler?(self)
    }
}

class NoHighlightButton: CustomLayoutButton {
    override var isHighlighted: Bool {
        get { super.isHighlighted }
        set {}
    }
}

