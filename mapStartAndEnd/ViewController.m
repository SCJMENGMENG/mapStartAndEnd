//
//  ViewController.m
//  mapStartAndEnd
//
//  Created by scj on 2018/9/11.
//  Copyright © 2018年 scj. All rights reserved.
//

#import "ViewController.h"
#import <MAMapKit/MAMapKit.h>
#import <AMapSearchKit/AMapSearchKit.h>
#import <AMapFoundationKit/AMapFoundationKit.h>

#import <MAMapKit/MAMapView.h>

#import "PlaceAroundTableView.h"

#define kTableViewMargin    8
#define kNaviBarHeight      60
#define kLocationButtonHeight      48

typedef NS_ENUM(NSInteger, CurrentGetLocationType)
{
    CurrentGetLocationTypeStart = 0,
    CurrentGetLocationTypeEnd = 1,
};

typedef NS_ENUM(NSInteger, CurrentAddressSettingType)
{
    CurrentAddressSettingTypeNone = 0,
    CurrentAddressSettingTypeHome = 1,
    CurrentAddressSettingTypeCompany = 2,
};


@interface ViewController ()<MAMapViewDelegate,AMapSearchDelegate,PlaceAroundTableViewDeleagate>

@property (nonatomic, strong) MAMapView *mapView;
@property (nonatomic, strong) AMapSearchAPI *search;

@property (nonatomic, strong) AMapReGeocodeSearchRequest *currentRegeoRequest;//逆地理使用
@property (nonatomic, assign) BOOL regeoSearchNeeded; //地图每次移动后是否需要进行逆地理请求

@property (nonatomic, strong) MAPointAnnotation *startAnnotation;
@property (nonatomic, strong) MAPointAnnotation *endAnnotation;


@property (nonatomic, strong) PlaceAroundTableView *tableview;
@property (nonatomic, strong) UIImageView *centerAnnotationView;
@property (nonatomic, assign) BOOL isMapViewRegionChangedFromTableView;

@property (nonatomic, assign) BOOL isLocated;

@property (nonatomic, strong) UIButton *locationBtn;
@property (nonatomic, strong) UIImage *imageLocated;
@property (nonatomic, strong) UIImage *imageNotLocate;

@property (nonatomic, assign) NSInteger searchPage;

@property (nonatomic, strong) UISegmentedControl *searchTypeSegment;
@property (nonatomic, copy) NSString *currentType;
@property (nonatomic, copy) NSArray *searchTypes;

@end

@implementation ViewController

#pragma mark - Utility

//根据中心点坐标来搜索周边的POI
- (void)searchPoiWithCenterCoordinate:(CLLocationCoordinate2D)coord{
    AMapPOIAroundSearchRequest *request = [[AMapPOIAroundSearchRequest alloc] init];
    
    request.location = [AMapGeoPoint locationWithLatitude:coord.latitude longitude:coord.longitude];
    
    request.radius = 1000;
    request.types = self.currentType;
    request.sortrule = 0;
    request.page = self.searchPage;
    
    [self.search AMapPOIAroundSearch:request];
}

- (void)searchReGeocodeWithCoordinate:(CLLocationCoordinate2D)coordinate{
    AMapReGeocodeSearchRequest *regeo = [[AMapReGeocodeSearchRequest alloc] init];
    
    regeo.location = [AMapGeoPoint locationWithLatitude:coordinate.latitude longitude:coordinate.longitude];
    regeo.requireExtension = YES;
    
    [self.search AMapReGoecodeSearch:regeo];
}

#pragma mark - MapViewDelegate
- (void)mapView:(MAMapView *)mapView regionDidChangeAnimated:(BOOL)animated{
    if (!self.isMapViewRegionChangedFromTableView && self.mapView.userTrackingMode == MAUserTrackingModeNone) {
        [self actionSearchAroundAt:self.mapView.centerCoordinate];
    }
    
    self.isMapViewRegionChangedFromTableView = NO;
}

#pragma mark - TableViewDelegate
- (void)didTableViewSelectedChanged:(AMapPOI *)selectedPoi{
    //防止连续点两次
    if (self.isMapViewRegionChangedFromTableView == YES) {
        return;
    }
    
    self.isMapViewRegionChangedFromTableView = YES;
    
    CLLocationCoordinate2D location = CLLocationCoordinate2DMake(selectedPoi.location.latitude, selectedPoi.location.longitude);
    
    [self.mapView setCenterCoordinate:location animated:YES];
}

-(void)didPositionCellTapped{
    //防止连续点两次
    if (self.isMapViewRegionChangedFromTableView == YES) {
        return;
    }
    
    self.isMapViewRegionChangedFromTableView = YES;
    
    [self.mapView setCenterCoordinate:self.mapView.userLocation.coordinate animated:YES];
}

-(void)didLoadMorePOIButtonTapped{
    self.searchPage ++;
    [self searchPoiWithCenterCoordinate:self.mapView.centerCoordinate];
}

#pragma mark - userLocation

-(void)mapView:(MAMapView *)mapView didUpdateUserLocation:(MAUserLocation *)userLocation updatingLocation:(BOOL)updatingLocation{
    if (!updatingLocation) {
        return;
    }
    if (userLocation.location.horizontalAccuracy < 0) {
        return;
    }
    
    // only the first locate used.
    if (!self.isLocated) {
        self.isLocated = YES;
        self.mapView.userTrackingMode = MAUserTrackingModeFollow;
        [self.mapView setCenterCoordinate:CLLocationCoordinate2DMake(userLocation.location.coordinate.latitude, userLocation.location.coordinate.longitude)];
        
        [self actionSearchAroundAt:userLocation.location.coordinate];
    }
}

- (void)mapView:(MAMapView *)mapView didChangeUserTrackingMode:(MAUserTrackingMode)mode animated:(BOOL)animated{
    if (mode == MAUserTrackingModeNone) {
        [self.locationBtn setImage:self.imageNotLocate forState:UIControlStateNormal];
    }else{
        [self.locationBtn setImage:self.imageLocated forState:UIControlStateNormal];
    }
}

-(void)mapView:(MAMapView *)mapView didFailToLocateUserWithError:(NSError *)error{
    NSLog(@"error = %@",error);
}

#pragma mark - Handke Action

- (void)actionSearchAroundAt:(CLLocationCoordinate2D)coordinate{
    [self searchReGeocodeWithCoordinate:coordinate];
    [self searchPoiWithCenterCoordinate:coordinate];
    
    self.searchPage = 1;
    [self centerAnnotaionAnimimate];
}

//定位按钮点击
- (void)actionLocation{
    if (self.mapView.userTrackingMode == MAUserTrackingModeFollow) {
        [self.mapView setUserTrackingMode:MAUserTrackingModeNone animated:YES];
    }else{
        self.searchPage = 1;
        
        [self.mapView setCenterCoordinate:self.mapView.userLocation.coordinate animated:YES];
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            // 因为下面这句的动画有bug，所以要延迟0.5s执行，动画由上一句产生
            [self.mapView setUserTrackingMode:MAUserTrackingModeFollow animated:YES];
        });
    }
}

-(void)actionTypeChanged:(UISegmentedControl *)sender{
    self.currentType = self.searchTypes[sender.selectedSegmentIndex];
    [self actionSearchAroundAt:self.mapView.centerCoordinate];
}

#pragma mark - Initialzation


- (void)initSearch
{
    self.searchPage = 1;
    self.search = [[AMapSearchAPI alloc] init];
    self.search.delegate = self.tableview;
}

- (void)initTableview
{
    self.tableview = [[PlaceAroundTableView alloc] initWithFrame:CGRectMake(0, self.view.bounds.size.height/2, CGRectGetWidth(self.view.bounds), self.view.bounds.size.height/2)];
    self.tableview.delegate = self;
    
    [self.view addSubview:self.tableview];
}

- (void)initCenterView
{
    self.centerAnnotationView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"wateRedBlank"]];
    self.centerAnnotationView.center = CGPointMake(self.mapView.center.x, self.mapView.center.y - CGRectGetHeight(self.centerAnnotationView.bounds) / 2);
    
    [self.mapView addSubview:self.centerAnnotationView];
}

- (void)initLocationButton
{
    self.imageLocated = [UIImage imageNamed:@"gpssearchbutton"];
    self.imageNotLocate = [UIImage imageNamed:@"gpsnormal"];
    
    self.locationBtn = [[UIButton alloc] initWithFrame:CGRectMake(CGRectGetWidth(self.mapView.bounds) - 40, CGRectGetHeight(self.mapView.bounds) - 50, 32, 32)];
    self.locationBtn.autoresizingMask = UIViewAutoresizingFlexibleTopMargin;
    self.locationBtn.backgroundColor = [UIColor whiteColor];
    
    self.locationBtn.layer.cornerRadius = 3;
    [self.locationBtn addTarget:self action:@selector(actionLocation) forControlEvents:UIControlEventTouchUpInside];
    [self.locationBtn setImage:self.imageNotLocate forState:UIControlStateNormal];
    
    [self.view addSubview:self.locationBtn];
}

- (void)initSearchTypeView{
    self.searchTypes = @[@"住宅",@"学校",@"楼宇",@"商场"];
    
    self.currentType = self.searchTypes.firstObject;
    
    self.searchTypeSegment = [[UISegmentedControl alloc] initWithItems:self.searchTypes];
    self.searchTypeSegment.frame = CGRectMake(10, CGRectGetHeight(self.mapView.bounds) - 50, CGRectGetWidth(self.mapView.bounds) - 80, 32);
    self.searchTypeSegment.layer.cornerRadius = 3;
    self.searchTypeSegment.backgroundColor = [UIColor whiteColor];
    self.searchTypeSegment.autoresizingMask = UIViewAutoresizingFlexibleTopMargin;
    self.searchTypeSegment.selectedSegmentIndex = 0;
    [self.searchTypeSegment addTarget:self action:@selector(actionTypeChanged:) forControlEvents:UIControlEventValueChanged];
    
    [self.view addSubview:self.searchTypeSegment];
}

//移动窗口弹一下的动画
- (void)centerAnnotaionAnimimate{
    [UIView animateWithDuration:0.5 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        CGPoint center = self.centerAnnotationView.center;
        center.y -= 20;
        [self.centerAnnotationView setCenter:center];
    } completion:nil];
    
    [UIView animateWithDuration:0.45 delay:0 options:UIViewAnimationOptionCurveEaseIn animations:^{
        CGPoint center = self.centerAnnotationView.center;
        center.y += 20;
        [self.centerAnnotationView setCenter:center];
    } completion:nil];
}


- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    [self initCenterView];
    [self initLocationButton];
    [self initSearchTypeView];
    
    self.mapView.zoomLevel = 17;
//    self.mapView.showsUserLocation = YES;
}


- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self initMapView];
    
    [self initControlButtons];
    
    [self addDefaultAnnotations];
    
    [self initTableview];
    [self initSearch];
}

- (void)initMapView{
    
    [AMapServices sharedServices].apiKey = @"00ba5ef4de63f606c26f4bf59ec8779c";
    
//    self.mapView = [[MAMapView alloc] initWithFrame:self.view.bounds];
    self.mapView = [[MAMapView alloc] initWithFrame:CGRectMake(0, 0, CGRectGetWidth(self.view.bounds), self.view.bounds.size.height/2)];
    self.mapView.delegate = self;
    self.mapView.showsScale = NO;
    self.mapView.showsCompass = NO;
    self.mapView.rotateEnabled = NO;
    self.mapView.rotateCameraEnabled = NO;
    
    self.mapView.runLoopMode = NSDefaultRunLoopMode;
    [self.mapView setShowsUserLocation:YES];
    
     [self.view addSubview:self.mapView];
    
    //search
    self.search = [[AMapSearchAPI alloc] init];
    self.search.delegate = self;
    
    self.isLocated = NO;
}

//在地图上添加起始和终点的标注点
- (void)addDefaultAnnotations {
    
    [self.mapView addAnnotation:self.startAnnotation];
    [self.mapView addAnnotation:self.endAnnotation];
    
//    [self.mapView showAnnotations:@[self.startAnnotation, self.endAnnotation] edgePadding:UIEdgeInsetsMake(120, 80, 140, 80) animated:YES];//控制放大缩小显示完全
}

- (MAAnnotationView *)mapView:(MAMapView *)mapView viewForAnnotation:(id<MAAnnotation>)annotation
{
    if ([annotation isKindOfClass:[MAUserLocation class]]) {
        return nil;
    }
    
    if ([annotation isKindOfClass:[MAPointAnnotation class]])
    {
        static NSString *pointReuseIndetifier = @"pointReuseIndetifier";
        MAAnnotationView *annotationView = (MAAnnotationView*)[mapView dequeueReusableAnnotationViewWithIdentifier:pointReuseIndetifier];
        if (annotationView == nil)
        {
            annotationView = [[MAAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:pointReuseIndetifier];
            
            annotationView.canShowCallout = NO;
        }
        
        annotationView.image = (annotation == self.startAnnotation) ? [UIImage imageNamed:@"default_navi_route_startpoint"] : [UIImage imageNamed:@"default_navi_route_endpoint"];
        annotationView.centerOffset = CGPointMake(0, -10);
        
        return annotationView;
    }
    
    return nil;
    
}



- (MAPointAnnotation *)startAnnotation
{
    if (_startAnnotation == nil) {
        _startAnnotation = [[MAPointAnnotation alloc] init];
        _startAnnotation.title = @"start";
        _startAnnotation.coordinate = CLLocationCoordinate2DMake(39.910267, 116.370888);
    }
    
    return _startAnnotation;
}

- (MAPointAnnotation *)endAnnotation
{
    if (_endAnnotation == nil) {
        _endAnnotation = [[MAPointAnnotation alloc] init];
        _endAnnotation.title = @"end";
        _endAnnotation.coordinate = CLLocationCoordinate2DMake(39.989872, 116.481956);
    }
    
    return _endAnnotation;
}


//定位按钮
-(void)initControlButtons{
    
    //location
    UIButton *buttonLocation = [[UIButton alloc] init];
    [buttonLocation setImage:[UIImage imageNamed:@"icon_location"] forState:UIControlStateNormal];
    [buttonLocation sizeToFit];
    buttonLocation.center = CGPointMake(10 + buttonLocation.bounds.size.width / 2.0, CGRectGetHeight(self.view.bounds) - 420 - buttonLocation.bounds.size.height / 2.0);
    [self.mapView addSubview:buttonLocation];
    
    [buttonLocation addTarget:self action:@selector(onLocationAction:) forControlEvents:UIControlEventTouchUpInside];
}

- (void)onLocationAction:(UIButton *)sender
{
    self.mapView.userTrackingMode = MAUserTrackingModeFollow;
    
//    if (self.regeoSearchNeeded) {
//        [self searchReGeocodeWithLocation:[AMapGeoPoint locationWithLatitude:self.mapView.userLocation.location.coordinate.latitude longitude:self.mapView.userLocation.location.coordinate.longitude]];
//    }
}

- (void)searchReGeocodeWithLocation:(AMapGeoPoint *)location
{
    AMapReGeocodeSearchRequest *regeo = [[AMapReGeocodeSearchRequest alloc] init];
    
    regeo.location = location;
    regeo.requireExtension = YES;
    [self.search AMapReGoecodeSearch:regeo];
    
    self.currentRegeoRequest = regeo;
}


@end
