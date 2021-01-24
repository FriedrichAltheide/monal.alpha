//
//  ContactsViewController.m
//  Monal
//
//  Created by Anurodh Pokharel on 6/14/13.
//
//

#import "ContactsViewController.h"
#import "MLContactCell.h"
#import "MLInfoCell.h"
#import "DataLayer.h"
#import "chatViewController.h"
#import "ContactDetails.h"
#import "addContact.h"
#import "CallViewController.h"
#import "MonalAppDelegate.h"
#import "UIColor+Theme.h"
#import "MLGroupChatTableViewController.h"
#import "xmpp.h"

@interface ContactsViewController ()

@property (nonatomic, strong) NSMutableArray<MLContact*>* searchResults ;
@property (nonatomic, strong) UISearchController* searchController;

@property (nonatomic, strong) NSMutableArray<MLContact*>* contacts;
@property (nonatomic, strong) MLContact* lastSelectedContact;

@end

@implementation ContactsViewController

#pragma mark view life cycle

-(void) viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    self.navigationItem.title=NSLocalizedString(@"Contacts", @"");
    
    self.contactsTable = self.tableView;
    self.contactsTable.delegate = self;
    self.contactsTable.dataSource = self;

    self.contacts = [[NSMutableArray alloc] init];
    self.searchResults = [[NSMutableArray alloc] init];
    
    [self.contactsTable reloadData];
    
    [self.contactsTable registerNib:[UINib nibWithNibName:@"MLContactCell"
                                    bundle:[NSBundle mainBundle]]
                                    forCellReuseIdentifier:@"ContactCell"];
    
    self.splitViewController.preferredDisplayMode=UISplitViewControllerDisplayModeAllVisible;
    
    self.searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    
    self.searchController.searchResultsUpdater = self;
    self.searchController.delegate = self;
    self.searchController.obscuresBackgroundDuringPresentation = NO;
    self.definesPresentationContext = YES;
    
    self.navigationItem.searchController = self.searchController;
    
    self.tableView.emptyDataSetSource = self;
    self.tableView.emptyDataSetDelegate = self;
    
    if(@available(iOS 13.0, *))
        self.navigationItem.rightBarButtonItem.image = [UIImage systemImageNamed:@"person.3.fill"];
    else
        self.navigationItem.rightBarButtonItem.image = [UIImage imageNamed:@"974-users"];
}

-(void) dealloc
{
}

-(void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    self.lastSelectedContact = nil;
    [self refreshDisplay];

    if(self.contacts.count == 0)
        [self reloadTable];
}


-(void) viewDidAppear:(BOOL) animated
{
    [super viewDidAppear:animated];
}


-(void) viewWillDisappear:(BOOL) animated
{
    [super viewWillDisappear:animated];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - jingle

-(void) showCallRequest:(NSNotification*) notification
{
    NSDictionary* dic = notification.object;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString* contactName = [dic objectForKey:@"user"];
        NSString* userName = [dic objectForKey:kUsername];

        UIAlertController* messageAlert =[UIAlertController alertControllerWithTitle:NSLocalizedString(@"Incoming Call", @"") message:[NSString stringWithFormat:NSLocalizedString(@"Incoming audio call to %@ from %@ ", @""),userName,  contactName] preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *acceptAction =[UIAlertAction actionWithTitle:NSLocalizedString(@"Accept", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            
            [self performSegueWithIdentifier:@"showCall" sender:dic];
            
            [[MLXMPPManager sharedInstance] handleCall:dic withResponse:YES];
        }];
        UIAlertAction* closeAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Decline" , @"") style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
            [[MLXMPPManager sharedInstance] handleCall:dic withResponse:NO];
        }];
        [messageAlert addAction:closeAction];
        [messageAlert addAction:acceptAction];

        [self.tabBarController presentViewController:messageAlert animated:YES completion:nil];
    });
}

#pragma mark - message signals

-(void) reloadTable
{
    if(self.contactsTable.hasUncommittedUpdates) return;
    
    [self.contactsTable reloadData];
}

-(void) refreshDisplay
{
    NSMutableArray* results = [[DataLayer sharedInstance] contactList];
    dispatch_async(dispatch_get_main_queue(), ^{
        self.contacts = results;
        [self reloadTable];
    });
    if(self.searchResults.count == 0)
    {
        dispatch_async(dispatch_get_main_queue(), ^{
          [self reloadTable];
        });
    }
}


#pragma mark - chat presentation
-(void) prepareForSegue:(UIStoryboardSegue*) segue sender:(id) sender
{
    if([segue.identifier isEqualToString:@"showDetails"])
    {
        UINavigationController* nav = segue.destinationViewController;
        ContactDetails* details = (ContactDetails *)nav.topViewController;
        details.contact = sender;
    }
    else if([segue.identifier isEqualToString:@"showGroups"])
    {
        MLGroupChatTableViewController* groups = (MLGroupChatTableViewController *)segue.destinationViewController;
        groups.selectGroup = ^(MLContact *selectedContact) {
            if(self.selectContact) self.selectContact(selectedContact);
            [self close:nil];
        };
    }
}

#pragma mark - Search Controller

-(void) didDismissSearchController:(UISearchController*) searchController;
{
    [self.searchResults removeAllObjects];
    [self reloadTable];
}

-(void) updateSearchResultsForSearchController:(UISearchController*) searchController;
{
    [self.searchResults removeAllObjects];
    if(searchController.searchBar.text.length > 0)
    {
        NSString* term = [searchController.searchBar.text copy];
        [self.searchResults addObjectsFromArray:[[DataLayer sharedInstance] searchContactsWithString:term]];
    }
    [self reloadTable];
}

#pragma mark - tableview datasource

-(NSString*) tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    return nil;
}

-(UISwipeActionsConfiguration*)tableView:(UITableView *)tableView leadingSwipeActionsConfigurationForRowAt:(NSIndexPath *)indexPath
{
    UIContextualAction* delete = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive title:NSLocalizedString(@"Delete", @"") handler:^(UIContextualAction*  action, __kindof UIView* sourceView, void (^ _Nonnull completionHandler)(BOOL)) {
        [self deleteRowAtIndexPath:indexPath];
    }];
    UIContextualAction* mute;
    MLContactCell* cell = (MLContactCell *)[tableView cellForRowAtIndexPath:indexPath];
    if(cell.muteBadge.hidden)
    {
        mute = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal title:NSLocalizedString(@"Mute", @"") handler:^(UIContextualAction*  action, __kindof UIView* sourceView, void (^ _Nonnull completionHandler)(BOOL)) {
            [self muteContactAtIndexPath:indexPath];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
            });
        }];
        [mute setBackgroundColor:[UIColor monalGreen]];
        
    } else  {
        mute = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal title:NSLocalizedString(@"Unmute", @"") handler:^(UIContextualAction*  action, __kindof UIView* sourceView, void (^ _Nonnull completionHandler)(BOOL)) {
            [self unMuteContactAtIndexPath:indexPath];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
            });
        }];
        [mute setBackgroundColor:[UIColor monalGreen]];
        
    }
    return [UISwipeActionsConfiguration configurationWithActions:@[delete, mute]];
}

-(MLContact*) contactAtIndexPath:(NSIndexPath*) indexPath
{
    return [self.contacts objectAtIndex:indexPath.row];
}

-(void) muteContactAtIndexPath:(NSIndexPath*) indexPath
{
    MLContact* contact = [self contactAtIndexPath:indexPath];
    if(contact)
        [[DataLayer sharedInstance] muteJid:contact.contactJid];
}

-(void) unMuteContactAtIndexPath:(NSIndexPath*) indexPath
{
    MLContact* contact = [self contactAtIndexPath:indexPath];
    if(contact)
        [[DataLayer sharedInstance] unMuteJid:contact.contactJid];
}


-(void) blockContactAtIndexPath:(NSIndexPath *) indexPath
{
    MLContact* contact = [self contactAtIndexPath:indexPath];
    if(contact)
        [[DataLayer sharedInstance] blockJid:contact.contactJid withAccountNo:contact.accountId];
}


-(NSInteger) numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView*) tableView numberOfRowsInSection:(NSInteger) section
{
    if(self.searchResults.count > 0)
        return [self.searchResults count];
    else
        return [self.contacts count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    MLContact* row = nil;
    if(self.searchResults.count > 0)
        row = [self.searchResults objectAtIndex:indexPath.row];
    else
        row = [self.contacts objectAtIndex:indexPath.row];
    
    MLContactCell* cell = [tableView dequeueReusableCellWithIdentifier:@"ContactCell"];
    if(!cell)
        cell = [[MLContactCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"ContactCell"];
    
    cell.count = 0;
    cell.userImage.image = nil;
    cell.statusText.text = @"";
    
    [cell showDisplayName:row.contactDisplayName];
    
    if(![row.statusMessage isEqualToString:@"(null)"] && ![row.statusMessage isEqualToString:@""])
        [cell showStatusText:row.statusMessage];
    else
        [cell showStatusText:nil];
    
    if(row.isGroup && row.groupSubject)
        [cell showStatusText:row.groupSubject];
    
    cell.accessoryType = UITableViewCellAccessoryDetailDisclosureButton;
    
    cell.accountNo = [row.accountId integerValue];
    cell.username = row.contactJid;

    NSNumber* unreadMessagesCnt = [[DataLayer sharedInstance] countUserUnreadMessages:cell.username forAccount:row.accountId];
    dispatch_async(dispatch_get_main_queue(), ^{
        cell.count = [unreadMessagesCnt integerValue];
    });

    [[MLImageManager sharedInstance] getIconForContact:row.contactJid andAccount:row.accountId withCompletion:^(UIImage *image) {
        cell.userImage.image = image;
    }];
    
    BOOL muted = [[DataLayer sharedInstance] isMutedJid:row.contactJid];
    dispatch_async(dispatch_get_main_queue(), ^{
        cell.muteBadge.hidden = !muted;
    });
    return cell;
}

#pragma mark - tableview delegate

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 60.0f;
}

-(NSString*) tableView:(UITableView*) tableView titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath*) indexPath
{
    return NSLocalizedString(@"Remove Contact",@"");
}

-(BOOL) tableView:(UITableView*) tableView canEditRowAtIndexPath:(NSIndexPath*) indexPath
{
    if(tableView == self.view)
        return YES;
    else
        return NO;
}

-(BOOL) tableView:(UITableView*) tableView shouldIndentWhileEditingRowAtIndexPath:(NSIndexPath*) indexPath
{
    if(tableView == self.view)
        return YES;
    else
        return NO;
}

-(void) deleteRowAtIndexPath:(NSIndexPath *) indexPath
{
    MLContact* contact = [self.contacts objectAtIndex:indexPath.row];
    NSString* messageString = [NSString stringWithFormat:NSLocalizedString(@"Remove %@ from contacts?", @""), contact.contactJid];
    NSString* detailString = NSLocalizedString(@"They will no longer see when you are online. They may not be able to access your encryption keys.", @"");
    
    if(contact.isGroup)
    {
        messageString = NSLocalizedString(@"Leave this converstion?", @"");
        detailString = nil;
    }
    
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:messageString
                                                                   message:detailString preferredStyle:UIAlertControllerStyleActionSheet];
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"No", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [alert dismissViewControllerAnimated:YES completion:nil];
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Yes", @"") style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        if(contact.isGroup)
            [[MLXMPPManager sharedInstance] leaveRoom:contact.contactJid withNick:contact.accountNickInGroup forAccountId:contact.accountId ];
        else
            [[MLXMPPManager sharedInstance] removeContact:contact];
        
        if(self.searchResults.count == 0) {
            [self.contactsTable beginUpdates];
            [self.contacts removeObjectAtIndex:indexPath.row];
            
            [self.contactsTable deleteRowsAtIndexPaths:@[indexPath]
                                      withRowAnimation:UITableViewRowAnimationAutomatic];
            [self.contactsTable endUpdates];
        }
        
    }]];
    alert.popoverPresentationController.sourceView = self.tableView;
    [self presentViewController:alert animated:YES completion:nil];
}

-(void) tableView:(UITableView*) tableView commitEditingStyle:(UITableViewCellEditingStyle) editingStyle forRowAtIndexPath:(NSIndexPath*) indexPath
{
    if(editingStyle == UITableViewCellEditingStyleDelete)
        [self deleteRowAtIndexPath:indexPath];
}

-(void) tableView:(UITableView*) tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath*) indexPath
{
    MLContact* contactDic;
    if(self.searchResults.count > 0)
        contactDic = [self.searchResults objectAtIndex:indexPath.row];
    else
        contactDic = [self.contacts objectAtIndex:indexPath.row];
    [self performSegueWithIdentifier:@"showDetails" sender:contactDic];
}

-(void) tableView:(UITableView*) tableView didSelectRowAtIndexPath:(NSIndexPath*) indexPath
{
    MLContact* row;
    
    if(self.searchResults.count > 0)
        row = [self.searchResults objectAtIndex:indexPath.row];
    else
    {
        if(indexPath.row < self.contacts.count)
            row = [self.contacts objectAtIndex:indexPath.row];
    }
    
    [self dismissViewControllerAnimated:YES completion:^{
        if(self.selectContact)
            self.selectContact(row);
    }];
    
}

#pragma mark - empty data set

-(UIImage*) imageForEmptyDataSet:(UIScrollView*) scrollView
{
    return [UIImage imageNamed:@"river"];
}

-(NSAttributedString*) titleForEmptyDataSet:(UIScrollView*) scrollView
{
    NSString *text = NSLocalizedString(@"You need friends for this ride", @"");
    
    NSDictionary *attributes = @{NSFontAttributeName: [UIFont boldSystemFontOfSize:18.0f],
                                 NSForegroundColorAttributeName: [UIColor darkGrayColor]};
    
    return [[NSAttributedString alloc] initWithString:text attributes:attributes];
}

-(NSAttributedString*) descriptionForEmptyDataSet:(UIScrollView*) scrollView
{
    NSString *text = NSLocalizedString(@"Add new contacts with the + button above. Your friends will pop up here when they can talk", @"");
    
    NSMutableParagraphStyle *paragraph = [NSMutableParagraphStyle new];
    paragraph.lineBreakMode = NSLineBreakByWordWrapping;
    paragraph.alignment = NSTextAlignmentCenter;
    
    NSDictionary* attributes = @{NSFontAttributeName: [UIFont systemFontOfSize:14.0f],
                                 NSForegroundColorAttributeName: [UIColor lightGrayColor],
                                 NSParagraphStyleAttributeName: paragraph};
    
    return [[NSAttributedString alloc] initWithString:text attributes:attributes];
}

-(UIColor*) backgroundColorForEmptyDataSet:(UIScrollView*) scrollView
{
    return [UIColor colorNamed:@"contacts"];
}

-(BOOL) emptyDataSetShouldDisplay:(UIScrollView*) scrollView
{
    if(self.contacts.count == 0)
    {
        // A little trick for removing the cell separators
        self.tableView.tableFooterView = [UIView new];
    }
    return self.contacts.count == 0;
}

-(IBAction) close:(id) sender
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
