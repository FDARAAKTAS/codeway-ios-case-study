import UIKit

class GroupCell: UICollectionViewCell {

    private let titleLabel = UILabel()
    private let countLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor.systemGray6
        layer.cornerRadius = 12

        titleLabel.font = .systemFont(ofSize: 18, weight: .medium)
        countLabel.font = .systemFont(ofSize: 16, weight: .regular)

        let stack = UIStackView(arrangedSubviews: [titleLabel, countLabel])
        stack.axis = .horizontal
        stack.distribution = .equalSpacing

        addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(name: String, count: Int) {
        titleLabel.text = name
        countLabel.text = "\(count)"
    }
}
