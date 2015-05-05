# Illiad/Alma NCIP Plug-in

Author: [Tom McNulty](mailto:tmcnulty@vcu.edu), VCU Libraries

This plug-in is based on the work of Hank Sway and Bill Jones for Harvard via IDS Group.  Originally the plug-in was designed for Aleph and ILLiad interaction via NCIP and I have modified their code with the help of Moshe Shechter at Ex Libris and Shawn Styer at Atlas Systems to work with Alma. You may find it helpful to look at [the original ILLiad NCIP plug-in and documentation](https://prometheus.atlas-sys.com/display/ILLiadAddons/IDS+NCIP+Client). I am happy to help with any questions or issues encountered in the process of implementing this plug-in but alas, I am but one man with a full time job so I cannot be the full technical support for any library hoping to run this plug-in.  If you implement this plug-in I recommend that you are or have technically qualified staff available to troubleshoot issues.

## Overview of functionality

The plug-in covers two ILL functions - borrowing and lending.

### Borrowing

When an item is checked in ILLiad the plug-in creates an NCIP request with the borrower's ID and a brief bib record.  This shows up as a request on the borrower's account in Alma (also viewable as a request via Primo). When the item is circulated in Alma it displays as a loan in the patron's account. The due date is set in ILLiad and honored in Alma. When the item is returned, it need only be returned in ILLiad. (It can be returned in Alma but it is not necessary.) At the point of return, ILLiad will send another message to Alma returning the item and removing it from the patron's account.

### Lending

When an item is "Marked as Found" in ILLiad the plug-in checks the Reference Number field in ILLiad for the item barcode (this must be input by the lending librarian).  When it matches, the item is then moved from the items home location to the Resource Sharing Lending library. When the item is returned and "Checked In" in ILLiad the plug-in sends a message to Alma and the item is marked as "In transit" to its home location.  It will need to be scanned in Alma and reshelved.

## Alma Configuration

(Also see Resource Sharing Requests in the Alma documentation for items not covered here)

Alma button -> Fulfillment -> Resource Sharing -> Partners

If you already have a Resource Sharing partner configured for ILLiad OpenURL linking you should be able to make the necessary adjustments to the configuration here without changing the current functionality (we use this to offer ILLiad interlibrary loan OpenURL links to items in our Primo instance).  I'll only cover the configuration options that are necessary for the plug-in to function.

### General Information

 - **Code** - Set this to your desired code.  This is the code that you use to address the resource sharing library via the plug in - ApplicationProfileType in the plug-in settings below.
 - **Profile Type** - NCIP
 - **System Type** - ILLiad
 - **Status** - Active
 - **Supports borrowing** - checked
 - **Supports lending** - checked

### Parameters
 
 - **User Identifier Type** - This should be the same as the user code in Illiad.  This will be the match point between the two systems.
 - **Default library owner** - Resource Sharing Library
 - **Check-out Item** - Default location  - Lending resource sharing requests
               - Default item policy - the plug-in is configured to use ILLiad set due dates and will override any settings here
 - **Receive Item** - Default location - Borrowing resource Sharing Requests
             - Default pickup library - select your default pickup location for Borrowing requests
             - Automatic receive - checked
             - Receive desk - Resource Sharing Desk

### Other Alma configuration issues

Make sure your Resource Sharing Library has open hours set.

## ILLiad Configuration:

### Installation

Create a new folder in your local machine's `ILLiad\Addons` directory (usually `C:\Program Files (x86)\ILLiad\Addons\`) and name it Alma-NCIP

Copy the three files - `Config.xml`, `IDS_NCIP_Client.lua`, and `sublibraries.txt` to the newly created directory.

### Settings

These are the settings that should be set through the Illiad systems plug-in interface. 

Make sure the plug-in is activated in the ILLiad client!

 - **NCIP_Responder_URL** - This setting value is the address for the NCIP Responder URL. For Alma this will always be https://alma.exlibrisgroup.com/view/NCIPServlet (unless you are testing on a sandbox version of Alma)
 - **acceptItem_from_uniqueAgency_value** - This is your institutional Alma Code.
 - **ApplicationProfileType** - This is the Resource Sharing Partner code used in Alma.
 - **BorrowingAcceptItemFailQueue** - This designates the name of the queue a Borrowing Transaction will be moved to if the BorrowingAcceptItem function fails.
 - **BorrowingCheckInItemFailQueue** - This designates the name of the queue a Borrowing Transaction will be moved to if the BorrowingCheckInItem function fails.
 - **LendingCheckOutItemFailQueue** - This designates the name of the queue a Lending Transaction will be moved to if the CheckOutItem function fails.
 - **LendingCheckInItemFailQueue** - This designates the name of the queue a Lending Transaction will be moved to if the CheckInItem function fails.
 - **EnablePatronBorrowingReturns** - When this setting is enabled, patron returns will go through ILLiad and a message is sent to Alma.  When this setting is disabled, patron returns will go through ILLiad and will need to also be returned through Alma.
 - **Use_Prefixes** - Determines whether or not you want to change prefixes of a transaction based on specific criteria (below).
 - **Prefix_for_LibraryUseOnly** - This setting allows you to change the prefix of a transaction that is marked LibraryUseOnly Yes.
 - **Prefix_for_RenewablesAllowed** - This setting allows you to change the prefix of a transaction that is marked RenewalsAllowed Yes.
 - **Prefix_for_LibraryUseOnly_and_RenewablesAllowed** - This setting allows you to change the prefix of a transaction that is marked both LibraryUseOnly and RenewalsAllowed Yes.

### Manual changes

This section is only necessary if you  use locations in ILLiad and need to designate more than one pick-up location for your borrowing requests.  I cannot offer support on this section (or guarantee it will work) as we do not use these options. Use at your own discression.

Update `sublibraries.txt` file:

 - Change the locations listed in this file to match your Alma locations
 - These should be library codes that may be used as pickup locations in the patron requests , for example MAIN,GRAD,BIO etc’.

Uncomment line 363 in the `.lua` file:

```-- m = m .. '<PickupLocation>' .. pickup_location .. '</PickupLocation>'```
