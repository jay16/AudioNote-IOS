//
//  ViewControllerFirst.m
//  AudioNote
//
//  Created by lijunjie on 14-12-6.
//  Copyright (c) 2014年 Intfocus. All rights reserved.
//
// 功能:
// 1. 语音转文字（科大讯飞）
// 2. 文句解析，找出相对应的分类。（/ProcessPattern)
// 3. 录入文句，解析结果写入数据库。（/DatabaseUtils)
// 3.1 写入数据库同时，post到服务器一份，作为改善算法的参考。

#import <UIKit/UIKit.h>
#import "ViewControllerFirst.h"
#import "ViewControllerSecond.h"
#import "ViewControllerThird.h"
#import "SettingsViewController.h"


#import "HttpUtils.h"
#import "ViewUtils.h"
#import "processPattern.h"
#import "DatabaseUtils.h"
#import "DataHelper.h"
#import "ISRDataHelper.h"
#import "HttpResponse.h"

#define kTopBarHeight 44.0
#define ScreenWidth [[UIScreen mainScreen] bounds].size.width
#define ScreenHeight [[UIScreen mainScreen] bounds].size.height

@interface ViewControllerFirst () <IFlySpeechRecognizerDelegate,UIActionSheetDelegate, UITableViewDelegate, UITableViewDataSource>

//识别对象（功能1）
@property (nonatomic, strong) IFlySpeechRecognizer * iFlySpeechRecognizer;
//数据上传对象（功能1）
@property (nonatomic, strong) IFlyDataUploader     * uploader;

@property (nonatomic, strong) MBProgressHUD        *progressHUD;
@property (assign, nonatomic) BOOL                 isCanceled;    // voice status
@property (assign, nonatomic) BOOL                 isNetWorkConnected;


// iFly recognizer convert audio to text. （功能1）
@property (strong, nonatomic) NSMutableString    *iFlyRecognizerResult;
@property (strong, nonatomic) NSDate             *iFlyRecognizerStartDate;
@property (strong, nonatomic) NSDateFormatter    *gDateFormatter;


// latest record list ui
@property (weak, nonatomic) IBOutlet UITableView *latestView;
@property (strong, nonatomic) NSMutableArray     *latestDataList;
@property (assign, nonatomic) NSInteger          listDataLimit;
@property (strong, nonatomic) DatabaseUtils      *databaseUtils;

// begin voice record
@property (weak, nonatomic) IBOutlet UIButton       *voiceBtn;

// 调整画面颜色
@property (weak, nonatomic) UIColor                 *gBackground;
@property (weak, nonatomic) UIColor                 *gTextcolor;
@property (weak, nonatomic) UIColor                 *gHighlightedTextColor;
@end


@implementation ViewControllerFirst
@synthesize iFlySpeechRecognizer;
@synthesize iFlyRecognizerResult;
@synthesize iFlyRecognizerStartDate;
@synthesize latestView;
@synthesize latestDataList;
@synthesize gDateFormatter;
@synthesize listDataLimit;
@synthesize gBackground;
@synthesize gTextcolor;

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.

    self.latestDataList = [NSMutableArray array];
    
    
    UIPinchGestureRecognizer *gesture = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(handlePinches:)];
    [self.latestView addGestureRecognizer:gesture];
    
    [self refresh];
}

-(void)handlePinches:(UIPinchGestureRecognizer *)paramSender{
    if(paramSender.state == UIGestureRecognizerStateBegan){
        NSLog(@"first page: pinch gesture.");
        
        SettingsViewController *settingsVC = [[SettingsViewController alloc] init];
        UINavigationController *navVC = [[UINavigationController alloc] initWithRootViewController:settingsVC];
        [self.view.window.rootViewController presentViewController:navVC animated:YES completion:nil];
    }
}


- (void) refresh {
    // latest n rows data list view
    self.listDataLimit = 5;
    self.latestView.delegate   = self;
    self.latestView.dataSource = self;

    
    // init Utils
    self.databaseUtils   = [[DatabaseUtils alloc] init];
    //[self.databaseUtils executeSQL: @"delete from voice_record"];
    self.isCanceled      = YES;
    
    // plist file config data read
    NSString* plist = [[NSBundle mainBundle] pathForResource:@"Info" ofType:@"plist"];
    NSMutableDictionary* dict = [[NSMutableDictionary alloc] initWithContentsOfFile:plist];
    dict = [dict objectForKey:@"IFly"];
    NSString *iflyAppId = [dict objectForKey:@"appid"];

    
    // config iflyRecognizer
    [IFlySetting setLogFile:LVL_NONE]; //未来查看科大讯飞日志时使用: LVL_ALL
    [IFlySetting showLogcat:NO];
    
    NSString *initString = [[NSString alloc] initWithFormat:@"appid=%@", iflyAppId];
    [IFlySpeechUtility createUtility:initString];
    // 创建识别
    self.iFlySpeechRecognizer = [ISRDataHelper CreateRecognizer:self Domain:@"iat"];
    self.uploader = [[IFlyDataUploader alloc] init];
    
    //NSLog(@"IFly Version: %@", [IFlySetting getVersion]);
    
    
    // recognizer result
    self.iFlyRecognizerResult = [[NSMutableString alloc] init];
    // global date foramt
    self.gDateFormatter = [[NSDateFormatter alloc] init];
    [self.gDateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    
    
    //self.latestView = [self.latestView initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 100)];
    self.latestView.backgroundColor = [UIColor clearColor];
    self.latestView.opaque = NO;
    self.parentViewController.view.backgroundColor = [UIColor colorWithRed:0.0 green:0.2 blue:0.5 alpha:0.7];
    //[self.latestView setEditing:YES animated:YES];
    
    
    self.latestDataList = [DataHelper getDataListWith: self.databaseUtils Limit: self.listDataLimit Offset: 0];
    
    if([self.latestDataList count] == 0) {
        NSMutableArray *mutableArray = [NSMutableArray arrayWithCapacity:0];
        NSMutableDictionary *mutableDictionary = [NSMutableDictionary dictionaryWithCapacity:0];
        
        [mutableDictionary setObject:@"欢迎使用【小6语记】记账" forKey:@"detail"];
        [mutableDictionary setObject:@"" forKey: @"category"];
        [mutableDictionary setObject:[NSNumber numberWithInteger:-1]  forKey:@"id"];
        [mutableArray addObject:mutableDictionary];
        
         mutableDictionary = [NSMutableDictionary dictionaryWithCapacity:0];
        [mutableDictionary setObject:@"1. 按住麦克风" forKey:@"detail"];
        [mutableDictionary setObject:@"" forKey: @"category"];
        [mutableDictionary setObject:[NSNumber numberWithInteger:-1]  forKey:@"id"];
        [mutableArray addObject:mutableDictionary];
        
        mutableDictionary = [NSMutableDictionary dictionaryWithCapacity:0];
        [mutableDictionary setObject:@"2. 说出你的时间、金钱花费" forKey:@"detail"];
        [mutableDictionary setObject:@"" forKey: @"category"];
        [mutableDictionary setObject:[NSNumber numberWithInteger:-1]  forKey:@"id"];
        [mutableArray addObject:mutableDictionary];
        
        mutableDictionary = [NSMutableDictionary dictionaryWithCapacity:0];
        [mutableDictionary setObject:@"如：	\"我花了580块买衣服\"" forKey:@"detail"];
        [mutableDictionary setObject:@"" forKey: @"category"];
        [mutableDictionary setObject:[NSNumber numberWithInteger:-1]  forKey:@"id"];
        [mutableArray addObject:mutableDictionary];
        
        mutableDictionary = [NSMutableDictionary dictionaryWithCapacity:0];
        [mutableDictionary setObject:@"	      \"昨天跑步1个半小时\"" forKey:@"detail"];
        [mutableDictionary setObject:@"" forKey: @"category"];
        [mutableDictionary setObject:[NSNumber numberWithInteger:-1]  forKey:@"id"];
        [mutableArray addObject:mutableDictionary];
        
        
        self.latestDataList = mutableArray;
    }
    // 开始录音按钮设置与启动
    [self.voiceBtn addTarget:self action:@selector(startVoiceRecord) forControlEvents:UIControlEventTouchDown];
    [self.voiceBtn addTarget:self action:@selector(stopVoiceRecord) forControlEvents:UIControlEventTouchUpInside];

    self.gBackground = [UIColor blackColor];
    self.gTextcolor  = [UIColor whiteColor];
    self.gHighlightedTextColor  = [UIColor orangeColor];
    
    // 无网络时，禁用[语音录入]按钮
    self.isNetWorkConnected = [HttpUtils isNetworkAvailable];
    self.voiceBtn.enabled = self.isNetWorkConnected;
    
    NSString *popText = [NSString stringWithFormat:@"网络: %@", [HttpUtils networkType]];
    [ViewUtils showPopupView:self.view Info:popText];
    
    [self.latestView reloadData];
}

- (void)viewDidUnload {
    //取消识别
    [self.iFlySpeechRecognizer cancel];
    [self.iFlySpeechRecognizer setDelegate: nil];
    self.iFlyRecognizerResult = nil;
    self.latestView = nil;
    self.latestDataList = nil;
    self.gDateFormatter = nil;
    self.databaseUtils  = nil;
    self.gBackground    = nil;
    self.gTextcolor     = nil;
    self.gHighlightedTextColor     = nil;
    
    [super viewDidUnload];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}



#pragma mark - Switch Voice Record

-(void)startVoiceRecord {
    _isCanceled = NO;
    //设置为录音模式
    [self.iFlySpeechRecognizer setParameter:IFLY_AUDIO_SOURCE_MIC forKey:@"audio_source"];
    bool ret = [self.iFlySpeechRecognizer startListening];
    if(ret) {
        // clear text when start recognizer tart
        self.iFlyRecognizerStartDate = [NSDate date];
        
        _progressHUD = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
        _progressHUD.labelText = @"请说话";
    } else {
        //可能是上次请求未结束，暂不支持多路并发
        [ViewUtils showPopupView:self.view Info:@"启动识别服务失败，请稍后重试"];
    }
}

// Stop Voice Record
-(void)stopVoiceRecord {
    // 按住麦克风说话， 松手后，应多录 半秒， 常发生手松的比较快，最后一个字没录上.
    [NSThread sleepForTimeInterval:0.5];
    
    [self.iFlySpeechRecognizer stopListening];
    _isCanceled = YES;
    
    [_progressHUD hide:YES];
}


#pragma mark - IFlySpeechRecognizerDelegate

/**
 * @fn      onVolumeChanged
 * @brief   音量变化回调
 *
 * @param   volume      -[in] 录音的音量，音量范围1~100
 * @see
 */
- (void) onVolumeChanged: (int)volume {
    if (_isCanceled) {
        [_progressHUD hide:YES];
        
        return;
    }
    NSString *vol = [NSString stringWithFormat:@"音量：%d",volume];
    //NSLog(@"isCanceled: %i, Volumne:%@", self.isCanceled, vol);
    //NSLog(@"iFlyRecognizerResult: %@", self.iFlyRecognizerResult.copy);
    _progressHUD.labelText = vol;
}

/**
 * @fn      onBeginOfSpeech
 * @brief   开始识别回调
 *
 * @see
 */
- (void) onBeginOfSpeech {
    NSLog(@"onBeginOfSpeech");
    
}

/**
 * @fn      onEndOfSpeech
 * @brief   停止录音回调
 *
 * @see
 */
- (void) onEndOfSpeech {
    NSLog(@"onEndOfSpeech");
}


/**
 * @fn      onError
 * @brief   识别结束回调
 *
 * @param   errorCode   -[out] 错误类，具体用法见IFlySpeechError
 */
- (void) onError:(IFlySpeechError *) error {
    NSLog(@"onError: %@",error);
}

/**
 * @fn      onResults
 * @brief   识别结果回调
 *
 * @param   result      -[out] 识别结果，NSArray的第一个元素为NSDictionary，NSDictionary的key为识别结果，value为置信度
 * @see
 */
- (void) onResults:(NSArray *) results isLast:(BOOL)isLast {
    // result数组内容很复杂，提取最简单的语音转义字符串
    NSMutableString *mutableString = [[NSMutableString alloc] init];
    NSDictionary    *dic = results[0];
    for (NSString *key in dic) {
        [mutableString appendFormat:@"%@",key];
    }
    NSString *resultStr = [[ISRDataHelper shareInstance] getResultFromJson:mutableString];
    //NSLog(@"听写结果：%@",resultStr);
    
    [self.iFlyRecognizerResult appendFormat:@"%@",resultStr];

    
    // 录音过程中，实时显示录音转义文句，暂时未使用到
    //self.iFlyRecognizerShow.text = self.iFlyRecognizerResult;
    
    // monitor whether recognize continue
    // operation only when finished converting
    if(isLast == YES) {
        if([self.iFlyRecognizerResult length] == 0) {
            [ViewUtils showPopupView:self.view Info:@"未创建"];
            [_progressHUD hide:YES];
        }
        else {
            // caculate duration
            NSTimeInterval duration = [self.iFlyRecognizerStartDate timeIntervalSinceNow];
            NSInteger t_duration    = round(duration < 0 ? -duration : duration);
            NSString *t_createTime  = [self.gDateFormatter stringFromDate:self.iFlyRecognizerStartDate];
            NSString *t_begin       = t_createTime.copy;

            NSLog(@"**************************");
            NSLog(@"content:  %@", self.iFlyRecognizerResult);
            NSLog(@"created:  %@", t_createTime);
            NSLog(@"duration: %li", t_duration);
            NSLog(@"**************************");
            
            
            ////////////////////////////////
            // Process input
            // All the result will be saved in g_szRemain, g_szType,g_nMoney,g_nTime
            ////////////////////////////////
            
            // 下面开始实现功能2
            // default value then not deal with failed
            NSString *t_nTime    = @"0";
            NSString *t_nMoney   = @"0";
            NSString *t_szType   = @"";
            NSString *t_szRemain = @"";
            NSString *t_szTime   = @"";
            
            char szTemp[MAX_INPUT_LEN];
            strcpy(szTemp,(char *)[self.iFlyRecognizerResult.copy UTF8String]);
            szTemp[MAX_INPUT_LEN-1] = '\0';
            if (process(szTemp, self.databaseUtils) == SUCCESS) {
                ////////////////////////////////
                // Insert to DB (process successfully)
                ////////////////////////////////
 
                t_nTime    = [NSString stringWithFormat:@"%d", g_nTime];
                t_nMoney   = [NSString stringWithFormat:@"%d", g_nMoney];
                t_szType   = [NSString stringWithUTF8String: g_szType];
                t_szRemain = [NSString stringWithUTF8String: g_szRemain];
                t_szTime   = [NSString stringWithUTF8String: g_szTime];
                NSLog(@"g_t_szTime: %@", t_szTime);
                
                NSString *_ymd_old = [t_createTime substringWithRange:NSMakeRange(0, 10)];
                
                t_createTime =[t_createTime stringByReplacingOccurrencesOfString:_ymd_old withString:t_szTime];
            }
            
            NSString *insertSQL = [NSString stringWithFormat: @"Insert into voice_record(input,description,category,nMoney,nTime,nDate,begin,duration,create_time,modify_time) VALUES('%@','%@','%@',%@,%@,'%@','%@',%li,'%@','%@');", self.iFlyRecognizerResult.copy, t_szRemain, t_szType, t_nMoney, t_nTime, t_szTime, t_begin, t_duration,  t_createTime, t_createTime];
            
            NSLog(@"Insert SQL:\n%@", insertSQL);
            
            NSInteger lastRowId = [self.databaseUtils executeSQL: insertSQL];
            if(lastRowId > 0)
                NSLog(@"Insert Into Database#%li - successfully.", lastRowId);
            else
                NSLog(@"Insert Into Database#%li - failed.", lastRowId);
            
            ////////////////////////////////
            // 3.1 写入数据库同时，post到服务器一份，作为改善算法的参考。
            ////////////////////////////////
            NSString *data = [NSString stringWithFormat:@"data={\"input\":\"%@\"", self.iFlyRecognizerResult.copy];
            data = [data stringByAppendingFormat:@", \"szRemain\":\"%@\"", t_szRemain];
            data = [data stringByAppendingFormat:@", \"szType\":\"%@\"", t_szType];
            data = [data stringByAppendingFormat:@", \"nMoney\":\"%@\"", t_nMoney];
            data = [data stringByAppendingFormat:@", \"nTime\":\"%@\"", t_nTime];
            data = [data stringByAppendingString:@"}"];
            NSMutableDictionary *params = [NSMutableDictionary dictionaryWithDictionary:@{@"data": @{@"input": self.iFlyRecognizerResult.copy, @"szRemain": t_szRemain, @"szType": t_szType, @"nMoney": t_nMoney, @"nTime":t_nTime}}];

//            if(self.isNetWorkConnected) {
//                HttpResponse *httpResponse = [DataHelper httpPostDeviceData:params];
//            }
            // 功能 3.1 END
            
            
            self.latestDataList = [DataHelper getDataListWith: self.databaseUtils Limit: self.listDataLimit Offset: 0];
            [self.latestView reloadData];
        }
        
        // set recognizer result empty
        [self.iFlyRecognizerResult setString:@""];
        NSLog(@"convert finished!");
    }
    // 2.a do nothing when continue
    else {
        NSLog(@"convert...");
    }
}

// iflyRecognizer callback functions over

#pragma mark - <UITableViewDelegate, UITableViewDataSource>


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.latestDataList count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellID = @"cellID";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellID];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:cellID];
    }
    cell.backgroundColor                 = self.gBackground;
    cell.textLabel.backgroundColor       = self.gBackground;
    cell.detailTextLabel.backgroundColor = self.gBackground;
    cell.textLabel.textColor       = self.gTextcolor;
    cell.detailTextLabel.textColor = self.gTextcolor;
    
    cell.textLabel.highlightedTextColor  = self.gHighlightedTextColor;
    cell.selectedBackgroundView = [[UIView alloc] initWithFrame:cell.frame];
    cell.selectedBackgroundView.backgroundColor = self.gBackground;
    
    NSMutableDictionary *dict = [self.latestDataList objectAtIndex:indexPath.row];
    cell.textLabel.text       = dict[@"detail"];
    cell.detailTextLabel.text = dict[@"category"];
    [cell.textLabel setFont:[UIFont systemFontOfSize:16.0]];
    [cell.detailTextLabel setFont:[UIFont systemFontOfSize:16.0]];
    
    // remove blue selection
    //cell.selectionStyle = UITableViewCellSelectionStyleNone;
    
    UILongPressGestureRecognizer *gesture = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleTableViewCellLongPress:)];
    [cell addGestureRecognizer:gesture];

    
    return cell;
}


#pragma mark - <UIAlertView>

- (void) handleTableViewCellLongPress:(UILongPressGestureRecognizer *)gesture{
    
    SettingsViewController *settingsVC = [[SettingsViewController alloc] init];
    UINavigationController *navVC = [[UINavigationController alloc] initWithRootViewController:settingsVC];
    [self.view.window.rootViewController presentViewController:navVC animated:YES completion:nil];
    return;
    
    
    if (gesture.state != UIGestureRecognizerStateBegan) {
        return;
    }
    
    UITableViewCell *cell = (UITableViewCell *)gesture.view;

    NSIndexPath *indexPath = [self.latestView indexPathForCell:cell];
    NSMutableDictionary *dict = [self.latestDataList objectAtIndex: indexPath.row];
    NSString *id = [NSString stringWithFormat:@"%@", dict[@"id"]];
    if (![id isEqualToString: @"-1"]) {
        NSString *msg = [NSString stringWithFormat:@"确认删除 - %@", dict[@"detail"]];
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"删除" message: msg delegate:self cancelButtonTitle:@"取消" otherButtonTitles:@"确定", nil];
        [alert setTag:indexPath.row];
        [alert show];
    }
}

-(void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex{
    NSInteger row = [alertView tag];
    if (buttonIndex == 0) {
        NSLog(@"取消: %ld", (long)row);
    }
    if(buttonIndex == 1) {
        NSLog(@"确定: %ld", (long)row);
        NSMutableDictionary *dict = [self.latestDataList objectAtIndex: row];
        NSString *id = [NSString stringWithFormat:@"%@", dict[@"id"]];
        NSLog(@"id: %@", id);
        if(![id isEqualToString: @"-1"]) {
            NSLog(@"%@", dict);
            [self.databaseUtils deleteWithId: id];
            [self refresh];
        } else {
            NSLog(@"let it go.");
        }
    }
}

#pragma mark - <CurrentShow>

- (void)didShowCurrent {
    [self refresh];
    NSLog(@"switch to first view.");
}

@end
