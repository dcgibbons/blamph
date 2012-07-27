//
//  MasterViewController.m
//  Blamph
//
//  Created by Chad Gibbons on 7/24/12.
//  Copyright (c) 2012 Nuclear Bunny Studios, LLC. All rights reserved.
//

#import "MasterViewController.h"
#import "ServerDefinition.h"
#import "LobbyViewController.h"
#import "MBProgressHUD.h"

@interface MasterViewController ()

@end

@implementation MasterViewController

@synthesize managedObjectContext = _managedObjectContext;
@synthesize nicknameField = _nicknameField;
@synthesize serverField = _serverField;
@synthesize client = _client;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    NSLog(@"masterviewcontroller init!");
    
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
//    nickname = @"chadwick";
    server = 0;
    servers = [NSMutableArray arrayWithObjects:
               [[ServerDefinition alloc] initWithName:@"default" andHostname:@"default.icb.net" andPort:7326],
               [[ServerDefinition alloc] initWithName:@"localhost" andHostname:@"localhost" andPort:7326],
               nil];
    
    self.nicknameField.text = nickname;
    
    ServerDefinition *s = (ServerDefinition *)[servers objectAtIndex:server];
    self.serverField.text = s.name;
    NSLog(@"setting default server to %@", s.name);
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
//    [nicknameField becomeFirstResponder];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView
{
    return 1;
}

- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component
{
    return 2;
}

- (NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component
{
    NSString *title = nil;
    ServerDefinition *s = (ServerDefinition *)[servers objectAtIndex:row];
    title = s.name;
    return title;
}

- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component
{
    server = row;
    ServerDefinition *s = (ServerDefinition *)[servers objectAtIndex:server];
    self.serverField.text = s.name;
    NSLog(@"setting server to %@", s.name);
}

- (void)done:(id)sender
{
    ServerDefinition *serverDefinition = (ServerDefinition *)[servers objectAtIndex:server];
    if ([nickname length] > 0 && serverDefinition != nil)
    {
        NSLog(@"Ready to connect as user %@ to server %@", nickname, serverDefinition);

        [sender resignFirstResponder];
        MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
        hud.labelText = @"Connecting";
        
        self.client = [[ICBClient alloc] initWithServer:serverDefinition andNickname:nickname];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(clientNotify:)
                                                     name:nil
                                                   object:self.client];
    }
}

- (void)clientNotify:(NSNotification *)notification
{
    NSLog(@"notification from client! %@", notification);
    if ([[notification name] compare:@"ICBClient:loginOK"] == NSOrderedSame)
    {
        [MBProgressHUD hideHUDForView:self.view animated:YES];
        [self performSegueWithIdentifier:@"connectSegue" sender:self];
    }
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([[segue identifier] isEqualToString:@"connectSegue"]) {
        NSLog(@"Preparing for segue, connectSegue, by passing ICBClient");
        UINavigationController *nc = (UINavigationController *)[segue destinationViewController];
        LobbyViewController *lvc = (LobbyViewController *)nc.topViewController;
        lvc.client = self.client;
    }
}

- (void)textFieldDidBeginEditing:(UITextField *)textField
{
    if (textField == self.serverField)
    {
        // TODO: creating these objects every time the text field gets focused is unncessarily expensive, so go ahead
        // and cache the views as needed, or don't worry about it?
        
        UIPickerView *picker = [[UIPickerView alloc] init];
        picker.dataSource = self;
        picker.delegate = self;
        picker.showsSelectionIndicator = YES;
        
        UIToolbar *toolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, 320, 40)];
        toolbar.barStyle = UIBarStyleBlackTranslucent;
        [toolbar setItems:[NSArray arrayWithObjects:
                           [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                                                         target:nil
                                                                         action:nil],
                           [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                         target:self
                                                                         action:@selector(done:)],
                           nil]];
        
        textField.inputView = picker;
        textField.inputAccessoryView = toolbar;
    }
}

- (void)textFieldDidEndEditing:(UITextField *)textField
{
    nickname = self.nicknameField.text;
    NSLog(@"Nickname changed to %@", nickname);                            
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    BOOL defaultBehavior = YES;
    
    if (textField == self.nicknameField)
    {
        NSLog(@"User pressed Done on the nicknameField");
        nickname = self.nicknameField.text;
        [self done:textField];
        defaultBehavior = NO;
    }
    
    return defaultBehavior;
}

@end
