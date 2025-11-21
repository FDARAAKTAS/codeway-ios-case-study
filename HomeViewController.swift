import UIKit
import SwiftUI
import Photos
import Combine

final class HomeViewController: UIViewController {
    
    private let viewModel = ScanViewModel()
    private var collectionView: UICollectionView!
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Progress UI

    private let progressContainer: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.isHidden = true
        return v
    }()

    private let scanStatusLabel: UILabel = {
        let lbl = UILabel()
        lbl.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        lbl.textColor = .label
        lbl.translatesAutoresizingMaskIntoConstraints = false
        return lbl
    }()

    private let progressView: UIProgressView = {
        let p = UIProgressView(progressViewStyle: .default)
        p.trackTintColor = .systemGray5
        p.progressTintColor = .systemBlue
        p.translatesAutoresizingMaskIntoConstraints = false
        return p
    }()
    
    private let cancelButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("Cancel", for: .normal)
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Photo Groups"
        view.backgroundColor = .systemBackground

        setupProgressContainer()
        setupCollectionView()
        setupObservers()
        setupActions()
        
        view.bringSubviewToFront(progressContainer)
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Scan",
            style: .plain,
            target: self,
            action: #selector(didTapScan)
        )
    }

    // MARK: - Scan Button

    @objc private func didTapScan() {
        // Case için: her seferinde baştan taramak daha anlaşılır
        requestPhotoAccessAndScan(resetExisting: true)
        // Eğer resume’i göstermek istersen:
        // requestPhotoAccessAndScan(resetExisting: false)
    }

    // MARK: - Permissions + Scan

    private func requestPhotoAccessAndScan(resetExisting: Bool) {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        
        switch status {
        case .authorized, .limited:
            viewModel.startScan(resetExisting: resetExisting)
            
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] newStatus in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    if newStatus == .authorized || newStatus == .limited {
                        self.viewModel.startScan(resetExisting: resetExisting)
                    } else {
                        self.showAccessDeniedAlert()
                    }
                }
            }
            
        case .denied, .restricted:
            showAccessDeniedAlert()
            
        @unknown default:
            break
        }
    }
    
    private func showAccessDeniedAlert() {
        let alert = UIAlertController(
            title: "Photo Access Required",
            message: "Please enable photo access in Settings to use this app.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Settings", style: .default) { _ in
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsURL)
            }
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    // MARK: - Progress UI Layout

    private func setupProgressContainer() {
        view.addSubview(progressContainer)
        progressContainer.addSubview(scanStatusLabel)
        progressContainer.addSubview(progressView)
        progressContainer.addSubview(cancelButton)

        NSLayoutConstraint.activate([
            progressContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 4),
            progressContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            progressContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            scanStatusLabel.topAnchor.constraint(equalTo: progressContainer.topAnchor),
            scanStatusLabel.leadingAnchor.constraint(equalTo: progressContainer.leadingAnchor),

            progressView.topAnchor.constraint(equalTo: scanStatusLabel.bottomAnchor, constant: 6),
            progressView.leadingAnchor.constraint(equalTo: progressContainer.leadingAnchor),
            progressView.trailingAnchor.constraint(equalTo: progressContainer.trailingAnchor),
            progressView.heightAnchor.constraint(equalToConstant: 4),
            
            cancelButton.topAnchor.constraint(equalTo: progressView.bottomAnchor, constant: 8),
            cancelButton.centerXAnchor.constraint(equalTo: progressContainer.centerXAnchor),
            cancelButton.bottomAnchor.constraint(equalTo: progressContainer.bottomAnchor)
        ])
    }
    
    private func setupActions() {
        cancelButton.addTarget(self, action: #selector(cancelScanTapped), for: .touchUpInside)
    }
    
    @objc private func cancelScanTapped() {
        viewModel.cancelScan()
    }

    // MARK: - CollectionView

    private func setupCollectionView() {
        let layout = UICollectionViewFlowLayout()

        let spacing: CGFloat = 12
        let totalSpacing = spacing * 4
        let width = view.bounds.width
        let cellWidth = (width - totalSpacing) / 3

        layout.itemSize = CGSize(width: cellWidth, height: 80)
        layout.minimumInteritemSpacing = spacing
        layout.minimumLineSpacing = spacing
        layout.sectionInset = UIEdgeInsets(top: 16, left: spacing, bottom: 16, right: spacing)

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.backgroundColor = .clear
        collectionView.register(GroupCell.self, forCellWithReuseIdentifier: "GroupCell")

        view.addSubview(collectionView)

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: progressContainer.bottomAnchor, constant: 8),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    // MARK: - Observers

    private func setupObservers() {
        viewModel.$processed
            .combineLatest(viewModel.$total, viewModel.$progress, viewModel.$isScanning)
            .receive(on: RunLoop.main)
            .sink { [weak self] processed, total, progress, isScanning in
                guard let self = self else { return }

                if isScanning {
                    if self.progressContainer.isHidden {
                        self.progressContainer.isHidden = false
                    }

                    let percent = Int(progress * 100)
                    self.scanStatusLabel.text =
                        "Scanning photos: \(percent)% (\(processed)/\(total))"

                    self.progressView.setProgress(Float(progress), animated: true)

                } else {
                    UIView.animate(withDuration: 0.3) {
                        self.progressContainer.alpha = 0
                    } completion: { _ in
                        self.progressContainer.isHidden = true
                        self.progressContainer.alpha = 1
                        self.scanStatusLabel.text = ""
                        self.progressView.setProgress(0, animated: false)
                    }
                }
            }
            .store(in: &cancellables)

        Publishers.CombineLatest(
            viewModel.$groups,
            viewModel.$others
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] _, _ in
            self?.collectionView.reloadData()
        }
        .store(in: &cancellables)
    }
}

// MARK: - CollectionView DataSource / Delegate

extension HomeViewController: UICollectionViewDataSource, UICollectionViewDelegate {

    private var allGroups: [(String, PhotoGroup?)] {
        let valid = PhotoGroup.allCases.compactMap { group -> (String, PhotoGroup?)? in
            let assets = viewModel.groups[group] ?? []
            return assets.isEmpty ? nil : (group.rawValue.uppercased(), group)
        }

        var result = valid
        if !viewModel.others.isEmpty {
            result.append(("OTHERS", nil))
        }

        return result
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        allGroups.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {

        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: "GroupCell",
            for: indexPath
        ) as? GroupCell else {
            return UICollectionViewCell()
        }

        let (name, group) = allGroups[indexPath.item]
        
        let count: Int
        if let group = group {
            count = viewModel.groups[group]?.count ?? 0
        } else {
            count = viewModel.others.count
        }
        
        cell.configure(name: name, count: count)
        return cell
    }

    func collectionView(_ collectionView: UICollectionView,
                        didSelectItemAt indexPath: IndexPath) {

        let (name, group) = allGroups[indexPath.item]

        let vm = GroupDetailViewModel(
            scanViewModel: viewModel,
            group: group,
            groupName: name
        )
        let detailVC = UIHostingController(rootView: GroupDetailView(vm: vm))
        navigationController?.pushViewController(detailVC, animated: true)
    }
}
