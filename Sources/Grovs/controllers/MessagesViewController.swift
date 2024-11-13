//
//  MessagesViewController.swift
//
//  grovs
//

import UIKit

/// A view controller for displaying a list of messages in a table view, with support for pull-to-refresh and pagination.
class MessagesViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UIScrollViewDelegate {

    static func loadVCFromNib() -> MessagesViewController? {
        var vc: MessagesViewController?

#if SWIFT_PACKAGE
        vc = MessagesViewController.init(nibName: "MessagesViewController", bundle: Bundle.module)
#else
        vc = MessagesViewController.init(nibName: "MessagesViewController", bundle: Bundle.framework)
#endif

        return vc
    }

    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!  // An activity indicator for loading state.
    @IBOutlet weak var tableView: UITableView!                     // The table view displaying the messages.
    @IBOutlet weak var titleLabel: UILabel!                        // The title label at the top of the screen.

    /// A struct containing constants used in the view controller.
    private struct Constants {
        static let cellIdentifier = "MessageTableViewCell"  // Identifier for the message table view cell.
    }

    var manager: GrovsManager?  // The manager responsible for fetching notifications.
    var dismissalDelegate: DismissalDelegate?

    private var notifications = [Notification]() {  // Array of notifications to be displayed.
        didSet {
            tableView.reloadData()
        }
    }

    private var isLoading = false       // A flag indicating whether data is currently loading.
    private var currentPage = 1         // Tracks the current page for pagination.
    private var canLoadMore = true      // Indicates if more data can be loaded for pagination.

    private let refreshControl = UIRefreshControl()  // Pull-to-refresh control.

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        // Register the table view cell and set data source and delegate.
#if SWIFT_PACKAGE
        tableView.register(UINib(nibName: "MessageTableViewCell", bundle: Bundle.module), forCellReuseIdentifier: Constants.cellIdentifier)
#else
        tableView.register(UINib(nibName: "MessageTableViewCell", bundle: Bundle.framework), forCellReuseIdentifier: Constants.cellIdentifier)
#endif

        tableView.dataSource = self
        tableView.delegate = self

        setupRefreshControl()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Refresh notifications when the view appears.
        refreshNotifications()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }

    override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        super.dismiss(animated: flag, completion: completion)

        // Notify the delegate when the view is dismissed
        dismissalDelegate?.viewControllerDidDismiss()
    }

    // MARK: - Setup Pull-to-Refresh

    /// Sets up the pull-to-refresh control.
    private func setupRefreshControl() {
        refreshControl.addTarget(self, action: #selector(refreshNotifications), for: .valueChanged)
        refreshControl.tintColor = .white
        tableView.refreshControl = refreshControl
    }

    // MARK: - Actions

    /// Dismisses the view controller.
    @IBAction func close(_ sender: Any) {
        self.dismiss(animated: true)
    }

    // MARK: - Table View Data Source

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return notifications.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: Constants.cellIdentifier, for: indexPath) as! MessageTableViewCell

        let notif = notifications[indexPath.row]

        // Configure the cell with notification data.
        cell.messageTitleLabel.text = notif.title
        cell.messageSubtitleLabel.text = notif.subtitle
        cell.newMessageIndicatorView.isHidden = notif.read

        return cell
    }

    // MARK: - Table View Delegate

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let notif = notifications[indexPath.row]
        goToMessage(notification: notif)
    }

    // MARK: - Pagination

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let offsetY = scrollView.contentOffset.y
        let contentHeight = scrollView.contentSize.height
        let frameHeight = scrollView.frame.size.height

        // Trigger loading more notifications when scrolled near the bottom.
        if offsetY > contentHeight - frameHeight - 100 {
            if !isLoading && canLoadMore {
                loadMoreNotifications()
            }
        }
    }

    /// Loads more notifications for the next page.
    private func loadMoreNotifications() {
        guard !isLoading else { return }
        isLoading = true
        currentPage += 1

        fetchNotifications(page: currentPage)
    }

    // MARK: - Pull to Refresh

    /// Refreshes the notifications list.
    @objc private func refreshNotifications() {
        currentPage = 1
        canLoadMore = true
        fetchNotifications(page: currentPage, isRefreshing: true)
    }

    // MARK: - Private Methods

    /// Navigates to the message details view controller.
    ///
    /// - Parameter notification: The selected notification.
    private func goToMessage(notification: Notification) {
        if let vc = MessageDetailsViewController.loadVCFromNib() {
            vc.notification = notification
            vc.manager = manager
            vc.dismissalDelegate = dismissalDelegate
            navigationController?.pushViewController(vc, animated: true)
        }
    }

    /// Fetches notifications from the manager.
    ///
    /// - Parameters:
    ///   - page: The page number to fetch.
    ///   - isRefreshing: Indicates if the fetch is triggered by a pull-to-refresh action.
    private func fetchNotifications(page: Int, isRefreshing: Bool = false) {
        if !isRefreshing {
            activityIndicator.startAnimating()
        }

        manager?.getNotifications(page: page, completion: { notifications in
            self.activityIndicator.stopAnimating()
            self.isLoading = false
            self.refreshControl.endRefreshing()

            guard let newNotifications = notifications else {
                AlertHelper.showGenericError()
                return
            }

            if isRefreshing {
                self.notifications = newNotifications // Replace existing data on refresh.
            } else {
                if newNotifications.isEmpty {
                    self.canLoadMore = false // Stop pagination when no more data is available.
                }
                self.notifications.append(contentsOf: newNotifications)
            }
        })
    }
}
