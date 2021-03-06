//
//  SettingsViewController.m
//  AudioNote
//
//  Created by lijunjie on 15/10/15.
//  Copyright © 2015年 Intfocus. All rights reserved.
//

#import "SettingsViewController.h"
#import "Version.h"
#import "const.h"
#import "DetailViewController.h"
#import "UpgradeViewController.h"
#import "NormalSettingsController.h"

@interface SettingsViewController() <UITableViewDataSource, UITableViewDelegate>
@property (weak, nonatomic) IBOutlet UITableView *listView;

@property (strong, nonatomic) NSArray *dataList;
@end

@implementation SettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    UIBarButtonItem *barItemBack = [[UIBarButtonItem alloc] initWithTitle:@"返回" style:UIBarButtonItemStylePlain target:self action:@selector(actionNavBack:)];
    self.navigationItem.rightBarButtonItem = barItemBack;
    self.navigationItem.title = @"设置";
    
    
    
    _dataList = @[
                  @[@"微信公众号", @"胜因"],
                  @[@"应用信息", [[Version alloc] init].current],
                  @[@"数据管理", @""],
                  @[@"版本更新", @""]
                  ];
    
    
    self.listView.backgroundColor = [UIColor whiteColor];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [_dataList count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cellID"];
    if(!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"cellID"];
    }
    
    NSArray *infos = _dataList[indexPath.row];
    cell.textLabel.text       = infos[0];
    cell.detailTextLabel.text = infos[1];
    
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    
    if(indexPath.row != SettingsWeixin) {
        cell.accessoryType  = UITableViewCellAccessoryDisclosureIndicator;
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    switch (indexPath.row) {
        case SettingsAppInfo: {
            
            DetailViewController *detailVC = [[DetailViewController alloc] init];
            detailVC.indexPath = indexPath.row;
            [self.navigationController pushViewController:detailVC animated:YES];
            
            break;
        }
        case SettingsExport: {
         
            NormalSettingsController *normalSettingsVC = [[NormalSettingsController alloc] init];
            [self.navigationController pushViewController:normalSettingsVC animated:YES];
            
            break;
        }
        case SettingsUpgrade: {
            
            UpgradeViewController *upgradeVC = [[UpgradeViewController alloc] init];
            [self.navigationController pushViewController:upgradeVC animated:YES];
            
            break;
        }
        default:
            break;
    }
}

- (void)actionNavBack:(UIBarButtonItem *)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
