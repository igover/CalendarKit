import UIKit

public protocol DayHeaderViewDelegate: AnyObject {
    func didTapOpDate(date: Date)
    func didMoveHeaderViewToDate(date: Date)
}

public final class DayHeaderView: UIView, DaySelectorDelegate, DayViewStateUpdating, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
  public private(set) var daysInWeek = 7
  public let calendar: Calendar
    public var selectedDate: Date? 

    public var delegate: DayHeaderViewDelegate?
    
  private var style = DayHeaderStyle()
  private var currentSizeClass = UIUserInterfaceSizeClass.compact

  public weak var state: DayViewState? {
    willSet(newValue) {
      state?.unsubscribe(client: self)
    }
    didSet {
      state?.subscribe(client: self)
      swipeLabelView.state = state
    }
  }

  private var currentWeekdayIndex = -1

  private var daySymbolsViewHeight: CGFloat = 20
  private var pagingScrollViewHeight: CGFloat = 40
  private var swipeLabelViewHeight: CGFloat = 30

  private let daySymbolsView: DaySymbolsView
  private var pagingViewController = UIPageViewController(transitionStyle: .scroll,
                                                       navigationOrientation: .horizontal,
                                                       options: nil)
  private let swipeLabelView: SwipeLabelView
  private lazy var separator: UIView = {
    let separator = UIView()
    separator.backgroundColor = SystemColors.systemSeparator
    return separator
  }()

  public init(calendar: Calendar) {
    self.calendar = calendar
    let symbols = DaySymbolsView(calendar: calendar)
    let swipeLabel = SwipeLabelView(calendar: calendar)
    self.swipeLabelView = swipeLabel
    self.daySymbolsView = symbols
    super.init(frame: .zero)
    configure()
  }

  @available(*, unavailable)
  required public init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
    
    public func switchModeTo(calendarMode: CalendarMode) {
        switch calendarMode {
        case .agenda:
            swipeLabelView.isHidden = true
        case .day:
            swipeLabelView.isHidden = false
        }
    }

  private func configure() {
    [daySymbolsView, swipeLabelView, separator].forEach(addSubview)
    backgroundColor = style.backgroundColor
    configurePagingViewController()
  }
  
  private func configurePagingViewController() {
    let selectedDate = Date()
    let daySelectorController = makeSelectorController(startDate: beginningOfWeek(selectedDate))
    daySelectorController.selectedDate = selectedDate
    currentWeekdayIndex = daySelectorController.selectedIndex
    
    let leftToRight = UIView.userInterfaceLayoutDirection(for: semanticContentAttribute) == .leftToRight
    let direction: UIPageViewController.NavigationDirection = leftToRight ? .forward : .reverse
    
    pagingViewController.setViewControllers([daySelectorController], direction: direction, animated: false, completion: nil)
    pagingViewController.dataSource = self
    pagingViewController.delegate = self
    addSubview(pagingViewController.view!)
  }
  
  private func makeSelectorController(startDate: Date) -> DaySelectorController {
    let daySelectorController = DaySelectorController()
    daySelectorController.calendar = calendar
    daySelectorController.transitionToHorizontalSizeClass(currentSizeClass)
    daySelectorController.updateStyle(style.daySelector)
    daySelectorController.startDate = startDate
    daySelectorController.delegate = self
    return daySelectorController
  }
  
  private func beginningOfWeek(_ date: Date) -> Date {
    let weekOfYear = component(component: .weekOfYear, from: date)
    let yearForWeekOfYear = component(component: .yearForWeekOfYear, from: date)
    return calendar.date(from: DateComponents(calendar: calendar,
                                              weekday: calendar.firstWeekday,
                                              weekOfYear: weekOfYear,
                                              yearForWeekOfYear: yearForWeekOfYear))!
  }

  private func component(component: Calendar.Component, from date: Date) -> Int {
    calendar.component(component, from: date)
  }
  
  public func updateStyle(_ newStyle: DayHeaderStyle) {
    style = newStyle
    daySymbolsView.updateStyle(style.daySymbols)
    swipeLabelView.updateStyle(style.swipeLabel)
    (pagingViewController.viewControllers as? [DaySelectorController])?.forEach{$0.updateStyle(newStyle.daySelector)}
    backgroundColor = style.backgroundColor
    separator.backgroundColor = style.separatorColor
  }

  override public func layoutSubviews() {
    super.layoutSubviews()
    daySymbolsView.frame = CGRect(origin: .zero,
                                  size: CGSize(width: bounds.width, height: daySymbolsViewHeight))
    pagingViewController.view?.frame = CGRect(origin: CGPoint(x: 0, y: daySymbolsViewHeight),
                                              size: CGSize(width: bounds.width, height: pagingScrollViewHeight))

      swipeLabelView.frame = CGRect(origin: CGPoint(x: 0, y: bounds.height - swipeLabelViewHeight),
                                    size: CGSize(width: bounds.width, height: swipeLabelViewHeight))
      
    let separatorHeight = 1 / UIScreen.main.scale
    separator.frame = CGRect(origin: CGPoint(x: 0, y: bounds.height - separatorHeight),
                             size: CGSize(width: bounds.width, height: separatorHeight))
  }

  public func transitionToHorizontalSizeClass(_ sizeClass: UIUserInterfaceSizeClass) {
    currentSizeClass = sizeClass
    (pagingViewController.children as? [DaySelectorController])?.forEach{$0.transitionToHorizontalSizeClass(sizeClass)}
  }

  // MARK: DaySelectorDelegate

  public func dateSelectorDidSelectDate(_ date: Date) {
    state?.move(to: date)
      delegate?.didTapOpDate(date: date)
      selectedDate = date
  }

  // MARK: DayViewStateUpdating

  public func move(from oldDate: Date, to newDate: Date) {
    let newDate = newDate.dateOnly(calendar: calendar)
      selectedDate = newDate
    let centerView = pagingViewController.viewControllers![0] as! DaySelectorController
    let startDate = centerView.startDate.dateOnly(calendar: calendar)

    let daysFrom = calendar.dateComponents([.day], from: startDate, to: newDate).day!
    let newStartDate = beginningOfWeek(newDate)

    let new = makeSelectorController(startDate: newStartDate)
    
    let leftToRight = UIView.userInterfaceLayoutDirection(for: semanticContentAttribute) == .leftToRight

    if daysFrom < 0 {
      currentWeekdayIndex = abs(daysInWeek + daysFrom % daysInWeek) % daysInWeek
      new.selectedIndex = currentWeekdayIndex
      
      let direction: UIPageViewController.NavigationDirection = leftToRight ? .reverse : .forward
        
      pagingViewController.setViewControllers([new], direction: direction, animated: true, completion: nil)
    } else if daysFrom > daysInWeek - 1 {
      currentWeekdayIndex = daysFrom % daysInWeek
      new.selectedIndex = currentWeekdayIndex
      
      let direction: UIPageViewController.NavigationDirection = leftToRight ? .forward : .reverse
        
      pagingViewController.setViewControllers([new], direction: direction, animated: true, completion: nil)
    } else {
      currentWeekdayIndex = daysFrom
      centerView.selectedDate = newDate
      centerView.selectedIndex = currentWeekdayIndex
    }
  }

  // MARK: UIPageViewControllerDataSource

  public func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
    if let selector = viewController as? DaySelectorController {
      let previousDate = calendar.date(byAdding: .weekOfYear, value: -1, to: selector.startDate)!
      return makeSelectorController(startDate: previousDate)
    }
    return nil
  }

  public func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
    if let selector = viewController as? DaySelectorController {
      let nextDate = calendar.date(byAdding: .weekOfYear, value: 1, to: selector.startDate)!
      return makeSelectorController(startDate: nextDate)
    }
    return nil
  }

  // MARK: UIPageViewControllerDelegate

  public func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
    guard completed else {return}
    if let selector = pageViewController.viewControllers?.first as? DaySelectorController {
      selector.selectedIndex = currentWeekdayIndex
      if let selectedDate = selector.selectedDate {
        state?.client(client: self, didMoveTo: selectedDate)
          delegate?.didMoveHeaderViewToDate(date: selectedDate)
      }
    }
    // Deselect all the views but the currently visible one
    (previousViewControllers as? [DaySelectorController])?.forEach{$0.selectedIndex = -1}
  }

    public func pageViewController(_ pageViewController: UIPageViewController, willTransitionTo pendingViewControllers: [UIViewController]) {
    (pendingViewControllers as? [DaySelectorController])?.forEach{$0.updateStyle(style.daySelector)}
  }
}
