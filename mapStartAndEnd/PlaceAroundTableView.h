//
//  PlaceAroundTableView.h
//  mapStartAndEnd
//
//  Created by scj on 2018/9/11.
//  Copyright © 2018年 scj. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MAMapKit/MAMapKit.h>
#import <AMapSearchKit/AMapSearchKit.h>

@protocol PlaceAroundTableViewDeleagate <NSObject>

- (void)didTableViewSelectedChanged:(AMapPOI *)selectedPoi;

- (void)didLoadMorePOIButtonTapped;

- (void)didPositionCellTapped;

@end

@interface PlaceAroundTableView : UIView <UITableViewDelegate,UITableViewDataSource,AMapSearchDelegate>

@property (nonatomic, weak) id<PlaceAroundTableViewDeleagate> delegate;

@property (nonatomic, copy) NSString *currentAddress;

- (instancetype)initWithFrame:(CGRect)frame;

- (AMapPOI *)selectedTableViewCellPoi;

@end
