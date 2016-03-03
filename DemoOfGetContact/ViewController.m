//
//  ViewController.m
//  DemoOfGetContact
//
//  Created by 吴 吴 on 15/10/12.
//  Copyright © 2015年 吴 吴. All rights reserved.
//

#import "ViewController.h"
#import <AddressBook/AddressBook.h>
#import <ContactsUI/ContactsUI.h>
#import "DetailViewController.h"

@interface ViewController ()<UITableViewDataSource,UITableViewDelegate>
{
    UITableView *infoTable;
    NSMutableArray *dataArray;
    NSMutableDictionary *dataSectionData;
    NSMutableArray *allKeysArray;
    NSMutableArray *sortkeysArray;
    
    /**
     *  创建CNContactStore对象,用与获取和保存通讯录信息
     */
    CNContactStore *contactStore;
}

@end

@implementation ViewController

- (id)init {
    self = [super init];
    if (self) {
        dataArray = [NSMutableArray array];
        allKeysArray = [NSMutableArray array];
        sortkeysArray = [NSMutableArray array];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setNavRightItem];
    [self setupUI];
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

#pragma mark - 自定义方法

- (void)setNavRightItem {
    UIBarButtonItem *rightItem = [[UIBarButtonItem alloc]initWithTitle:@"刷新" style:UIBarButtonItemStylePlain target:self action:@selector(rightItemPressed)];
    self.navigationItem.rightBarButtonItem = rightItem;
}

#pragma mark - 创建UI

- (void)setupUI {
    infoTable = [[UITableView alloc]initWithFrame:CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.width, self.view.frame.size.height) style:UITableViewStylePlain];
    infoTable.backgroundColor = [UIColor clearColor];
    infoTable.dataSource = self;
    infoTable.delegate = self;
    infoTable.sectionIndexColor = [UIColor blackColor];
    infoTable.sectionIndexBackgroundColor = [UIColor clearColor];
    [self.view addSubview:infoTable];
    
    [self getAllContactsByContact];
}

#pragma mark - 按钮点击事件

- (void)rightItemPressed {
    [self fetchContactWithContactStore:contactStore];
    [infoTable reloadData];
}

#pragma mark - 数据源

/**
 *  获取所有本地所有联系人 ios9前
 */
- (void)getAllContactsByAdressBook {
    /**
     *  取得本地通信录名柄
     */
    ABAddressBookRef tmpAddressBook = nil;
    
    if ([[UIDevice currentDevice].systemVersion floatValue]>=6.0)
    {
        tmpAddressBook=ABAddressBookCreateWithOptions(NULL, NULL);
        dispatch_semaphore_t sema=dispatch_semaphore_create(0);
        ABAddressBookRequestAccessWithCompletion(tmpAddressBook, ^(bool greanted, CFErrorRef error){
            dispatch_semaphore_signal(sema);
        });
        
        dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
    }
    else
    {
        tmpAddressBook =ABAddressBookCreate();
    }
    /**
     *  取得本地所有联系人记录
     */
    if (tmpAddressBook==nil) {
        return ;
    };
    NSArray* allContactsArray = (__bridge NSArray*)ABAddressBookCopyArrayOfAllPeople(tmpAddressBook);
    dataArray = [NSMutableArray arrayWithArray:allContactsArray];
    CFRelease(tmpAddressBook);
}

/**
 *  获取所有本地所有联系人 ios9后
 */
- (void)getAllContactsByContact {
    /**
     * 首次访问通讯录会调用
     */
    contactStore = [[CNContactStore alloc] init];
    if ([CNContactStore authorizationStatusForEntityType:CNEntityTypeContacts] == CNAuthorizationStatusNotDetermined)
    {
        [contactStore requestAccessForEntityType:CNEntityTypeContacts completionHandler:^(BOOL granted, NSError * _Nullable error)
         {
             if (error) return;
             if (granted)
             {
                 NSLog(@"授权访问通讯录");
                 [self fetchContactWithContactStore:contactStore];
             }
             else
             {
                 NSLog(@"拒绝访问通讯录");
             }
         }];
    }
    else
    {
        [self fetchContactWithContactStore:contactStore];
    }
}

- (void)fetchContactWithContactStore:(CNContactStore *)cnContactStore {
    
    [dataArray removeAllObjects];
    /**
     *  有权限访问
     */
    if ([CNContactStore authorizationStatusForEntityType:CNEntityTypeContacts] == CNAuthorizationStatusAuthorized)
    {
        NSError *error = nil;
        
        /**
         *  关键:创建数组,必须遵守CNKeyDescriptor协议,放入相应的字符串常量来获取对应的联系人信息(用户的信息都有对应的key，选取指定的key获取对应信息)
         */
        NSArray <id<CNKeyDescriptor>> *keysToFetch = @[CNContactFamilyNameKey, CNContactGivenNameKey, CNContactPhoneNumbersKey,CNContactImageDataKey];
        
        
        /**
         * 创建获取联系人的请求
         */
        CNContactFetchRequest *fetchRequest = [[CNContactFetchRequest alloc] initWithKeysToFetch:keysToFetch];
        
        
        /**
         *  遍历查询通讯录所有联系人
         */
        [contactStore enumerateContactsWithFetchRequest:fetchRequest error:&error usingBlock:^(CNContact * _Nonnull contact, BOOL * _Nonnull stop)
         {
             if (!error)
             {
                 NSLog(@"familyName = %@", contact.familyName);//姓
                 NSLog(@"givenName = %@", contact.givenName);//名字
                 NSLog(@"phoneNumber = %@", ((CNPhoneNumber *)(contact.phoneNumbers.lastObject.value)).stringValue);//电话
                 [dataArray addObject:contact];
             }
             else
             {
                 NSLog(@"error:%@", error.localizedDescription);
             }
         }];
        [self createSectionData];
    }
    else
    {
        NSLog(@"拒绝访问通讯录");
    }
}

#pragma mark - UITableViewSource && Delegate

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return sortkeysArray.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSString *key = sortkeysArray.count>0 ? sortkeysArray[section]:@"";
    NSArray *arr = [dataSectionData objectForKey:key];
    return arr.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 44.0;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 44.0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellID = @"myCell";
    UITableViewCell *cell = (UITableViewCell *)[tableView dequeueReusableCellWithIdentifier:cellID];
    if (cell == nil) {
        cell = [[UITableViewCell alloc]initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellID];
    }
    cell.backgroundColor = [UIColor clearColor];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    
    //    id tempPerson = dataArray[indexPath.row];
    //    NSString* tmpFirstName = (__bridge NSString*)ABRecordCopyValue((__bridge ABRecordRef)(tempPerson), kABPersonFirstNameProperty);
    NSArray *arr = [dataSectionData objectForKey:sortkeysArray[indexPath.section]];
    CNContact *tempConact = arr[indexPath.row];
    NSString *phone = ((CNPhoneNumber *)(tempConact.phoneNumbers.lastObject.value)).stringValue;
    cell.textLabel.text = [NSString stringWithFormat:@"%@     %@",tempConact.givenName,phone];
    return cell;
}

- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView {
    return sortkeysArray;
}

- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index {
    NSLog(@"1232132");
    return [sortkeysArray indexOfObject:title];
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    
    UIView *headerView = [[UIView alloc]initWithFrame:CGRectMake(0, 0,infoTable.frame.size.width, 44)];
    headerView.backgroundColor = [UIColor grayColor];
    
    UILabel *titleLbl = [[UILabel alloc]initWithFrame:CGRectMake(15,13, 200, 18)];
    titleLbl.textAlignment = NSTextAlignmentLeft;
    titleLbl.textColor = [UIColor blackColor];
    titleLbl.font = [UIFont systemFontOfSize:18.0];
    titleLbl.text  = sortkeysArray[section];
    [headerView addSubview:titleLbl];
    
    return headerView;
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    DetailViewController *vc = [[DetailViewController alloc]init];
    
    NSString *key = sortkeysArray[indexPath.section];
    NSArray *contactsArr = [dataSectionData objectForKey:key];
    vc.tempContact = contactsArr[indexPath.row];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)createSectionData
{
    if (dataSectionData==nil)
    {
        dataSectionData = [[NSMutableDictionary alloc] init];
    }
    else
    {
        [dataSectionData removeAllObjects];
    }
    NSLog(@"🍎--%@",dataArray);
    for (CNContact *model in dataArray)
    {
        NSString *sectionKey = @"";
        
        
        /**
         *  将姓名转换成拼音,并取名字拼音的首字母 ,得不到拼音首字母的归类至?
         */
        NSString *pingYinName = [self transformMandarinToLatin:model.givenName];
        sectionKey =  pingYinName.length>0?[pingYinName substringToIndex:1]:@"?";
        
        /**
         *  将首字母转换成大写
         */
        sectionKey = [sectionKey uppercaseString];
        
        NSMutableArray *sectionArray = [dataSectionData objectForKey:sectionKey];
        NSLog(@"sectionArray-%@",sectionArray);
        if (sectionArray == nil)
        {
            [allKeysArray addObject:sectionKey];
            sectionArray = [[NSMutableArray alloc] init];
            [dataSectionData setObject:sectionArray forKey:sectionKey];
        }
        [sectionArray addObject:model];
    }
    
    NSLog(@"allKeysArray-%@",allKeysArray);
    NSLog(@"dataSection-%@",dataSectionData);
    NSArray *sortKeysArr = [allKeysArray sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        return [obj1 compare:obj2 options:NSNumericSearch];
    }];
    [sortkeysArray addObjectsFromArray:sortKeysArr];
    NSLog(@"%@",sortKeysArr);
}

- (void)sortAllContactByFristPinying {
    
}

- (NSString*) transformMandarinToLatin:(NSString *)string {
    if ([string length]==0) return string;
    
    NSMutableString *preString = [string mutableCopy];
    CFStringTransform((CFMutableStringRef)preString, NULL, kCFStringTransformMandarinLatin,NO);
    CFStringTransform((CFMutableStringRef)preString, NULL,kCFStringTransformStripDiacritics, NO);
    if ([[(NSString *)string substringToIndex:1] compare:@"长"] ==NSOrderedSame) {
        [preString replaceCharactersInRange:NSMakeRange(0, 5)withString:@"chang"];
    }
    if ([[(NSString *)string substringToIndex:1] compare:@"沈"] ==NSOrderedSame) {
        [preString replaceCharactersInRange:NSMakeRange(0, 4)withString:@"shen"];
    }
    if ([[(NSString *)string substringToIndex:1] compare:@"厦"] ==NSOrderedSame) {
        [preString replaceCharactersInRange:NSMakeRange(0, 3)withString:@"xia"];
    }
    if ([[(NSString *)string substringToIndex:1] compare:@"地"] ==NSOrderedSame) {
        [preString replaceCharactersInRange:NSMakeRange(0, 3)withString:@"di"];
    }
    if ([[(NSString *)string substringToIndex:1] compare:@"重"] ==NSOrderedSame) {
        [preString replaceCharactersInRange:NSMakeRange(0, 5) withString:@"chong"];
    }
    return preString;
}

@end
