--About IDS_NCIP_Client 1.5
--
--Author:  Bill Jones III, SUNY Geneseo, IDS Project, jonesw@geneseo.edu
--Modified by: Tom McNulty, VCU Libraries, tmcnulty@vcu.edu
--Modified by: Kevin Reiss, Princeton University Library, kr2@princeton.edu; Peter Green, Princeton University Library, pmgreen@princeton.edu; Mark Zelesky, Princeton University Library, mzelesky@princeton.edu
--System Addon used for ILLiad to communicate with Alma through NCIP protocol
--
--Description of Registered Event Handlers for ILLiad
--
--BorrowingRequestCheckedInFromLibrary
--This will trigger whenever a non-cancelled transaction is processed from the Check In From Lending Library
--batch processing form using the Check In, Check In Scan Now, or Check In Scan Later buttons.
--
--BorrowingRequestCheckedInFromCustomer
--This will trigger whenever an item is processed from the Check Item In batch processing form,
--regardless of its status (such as if it were cancelled or never picked up by the customer).
--
--LendingRequestCheckOut
--This will trigger whenever a transaction is processed from the Lending Update Stacks Searching form
--using the Mark Found or Mark Found Scan Now buttons. This will also work on the Lending Processing ribbon
--of the Request form for the Mark Found and Mark Found Scan Now buttons.
--
--LendingRequestCheckIn
--This will trigger whenever a transaction is processed from the Lending Returns batch processing form.
--
--Queue names have a limit of 40 characters (including spaces).


local Settings = {};

--NCIP Responder URL
Settings.NCIP_Responder_URL = GetSetting("NCIP_Responder_URL");

--Change Prefix Settings for Transactions
Settings.Use_Prefixes = GetSetting("Use_Prefixes");
Settings.Prefix_for_LibraryUseOnly = GetSetting("Prefix_for_LibraryUseOnly");
Settings.Prefix_for_RenewablesAllowed = GetSetting("Prefix_for_RenewablesAllowed");
Settings.Prefix_for_LibraryUseOnly_and_RenewablesAllowed = GetSetting("Prefix_for_LibraryUseOnly_and_RenewablesAllowed");

--NCIP Error Status Changes
Settings.BorrowingAcceptItemFailQueue = GetSetting("BorrowingAcceptItemFailQueue");
Settings.BorrowingCheckInItemFailQueue = GetSetting("BorrowingCheckInItemFailQueue");
Settings.LendingCheckOutItemFailQueue = GetSetting("LendingCheckOutItemFailQueue");
Settings.LendingCheckInItemFailQueue = GetSetting("LendingCheckInItemFailQueue");

--acceptItem settings
Settings.acceptItem_from_uniqueAgency_value = GetSetting("acceptItem_from_uniqueAgency_value");
Settings.acceptItem_Transaction_Prefix = GetSetting("checkInItem_Transaction_Prefix");

--checkInItem settings
Settings.checkInItem_EnablePatronBorrowingReturns = GetSetting("EnablePatronBorrowingReturns");
Settings.ApplicationProfileType = GetSetting("ApplicationProfileType");
Settings.checkInItem_Transaction_Prefix = GetSetting("checkInItem_Transaction_Prefix");

--checkOutItem settings
Settings.checkOutItem_RequestIdentifierValue_Prefix = GetSetting("checkOutItem_RequestIdentifierValue_Prefix");

function Init()
	RegisterSystemEventHandler("BorrowingRequestCheckedInFromLibrary", "BorrowingAcceptItem");
	RegisterSystemEventHandler("BorrowingRequestCheckedInFromCustomer", "BorrowingCheckInItem");
	RegisterSystemEventHandler("LendingRequestCheckOut", "LendingCheckOutItem");
	RegisterSystemEventHandler("LendingRequestCheckIn", "LendingCheckInItem");
end

--Borrowing Functions
function BorrowingAcceptItem(transactionProcessedEventArgs)
	LogDebug("BorrowingAcceptItem - start");

	if GetFieldValue("Transaction", "RequestType") == "Loan" then

	LogDebug("Item Request has been identified as a Loan and not Article - process started.");

	luanet.load_assembly("System");
	local ncipAddress = Settings.NCIP_Responder_URL;
	local BAImessage = buildAcceptItem();
	LogDebug("creating BorrowingAcceptItem message[" .. BAImessage .. "]");
	local WebClient = luanet.import_type("System.Net.WebClient");
	local myWebClient = WebClient();
	LogDebug("WebClient Created");
	LogDebug("Adding Header");

	LogDebug("Setting Upload String");
	local BAIresponseArray = myWebClient:UploadString(ncipAddress, BAImessage);
	LogDebug("Upload response was[" .. BAIresponseArray .. "]");

	LogDebug("Starting error catch")
	local currentTN = GetFieldValue("Transaction", "TransactionNumber");

	if string.find (BAIresponseArray, "Item Not Checked Out") then
	LogDebug("NCIP Error: Item Not Checked Out");
	ExecuteCommand("Route", {currentTN, "NCIP Error: BorAcceptItem-NotCheckedOut"});
	LogDebug("Adding Note to Transaction with NCIP Client Error");
	ExecuteCommand("AddNote", {currentTN, BAIresponseArray});
    SaveDataSource("Transaction");

	elseif string.find(BAIresponseArray, "User Authentication Failed") then
	LogDebug("NCIP Error: User Authentication Failed");
	ExecuteCommand("Route", {currentTN, "NCIP Error: BorAcceptItem-UserAuthFail"});
	LogDebug("Adding Note to Transaction with NCIP Client Error");
	ExecuteCommand("AddNote", {currentTN, BAIresponseArray});
    SaveDataSource("Transaction");

	--this error came up from non-standard characters in the title (umlauts)
	elseif string.find(BAIresponseArray, "Service is not known") then
	LogDebug("NCIP Error: ReRouting Transaction");
	ExecuteCommand("Route", {currentTN, "NCIP Error: BorAcceptItem-SrvcNotKnown"});
	LogDebug("Adding Note to Transaction with NCIP Client Error");
	ExecuteCommand("AddNote", {currentTN, BAIresponseArray});
    SaveDataSource("Transaction");

	elseif string.find(BAIresponseArray, "Problem") then
	LogDebug("NCIP Error: ReRouting Transaction");
	ExecuteCommand("Route", {currentTN, Settings.BorrowingAcceptItemFailQueue});
	LogDebug("Adding Note to Transaction with NCIP Client Error");
	ExecuteCommand("AddNote", {currentTN, BAIresponseArray});
    SaveDataSource("Transaction");

	else
	LogDebug("No Problems found in NCIP Response.")
	ExecuteCommand("AddNote", {currentTN, "NCIP Response for BorrowingAcceptItem received successfully"});
    SaveDataSource("Transaction");
	end
	end
end


function BorrowingCheckInItem(transactionProcessedEventArgs)

	LogDebug("BorrowingCheckInItem - start");
	luanet.load_assembly("System");
	local ncipAddress = Settings.NCIP_Responder_URL;
	local BCIImessage = buildCheckInItemBorrowing();
	LogDebug("creating BorrowingCheckInItem message[" .. BCIImessage .. "]");
	local WebClient = luanet.import_type("System.Net.WebClient");
	local myWebClient = WebClient();
	LogDebug("WebClient Created");
	LogDebug("Adding Header");
	myWebClient.Headers:Add("Content-Type", "text/xml; charset=UTF-8");
	LogDebug("Setting Upload String");
	local BCIIresponseArray = myWebClient:UploadString(ncipAddress, BCIImessage);
	LogDebug("Upload response was[" .. BCIIresponseArray .. "]");

	LogDebug("Starting error catch")
	local currentTN = GetFieldValue("Transaction", "TransactionNumber");

	if string.find(BCIIresponseArray, "Unknown Item") then
	LogDebug("NCIP Error: ReRouting Transaction");
	ExecuteCommand("Route", {currentTN, "NCIP Error: BorCheckIn-UnknownItem"});
	LogDebug("Adding Note to Transaction with NCIP Client Error");
	ExecuteCommand("AddNote", {currentTN, BCIIresponseArray});
    SaveDataSource("Transaction");

	elseif string.find(BCIIresponseArray, "Item Not Checked Out") then
	LogDebug("NCIP Error: ReRouting Transaction");
	ExecuteCommand("Route", {currentTN, "NCIP Error: BorCheckIn-NotCheckedOut"});
	LogDebug("Adding Note to Transaction with NCIP Client Error");
	ExecuteCommand("AddNote", {currentTN, BCIIresponseArray});
    SaveDataSource("Transaction");

	elseif string.find(BCIIresponseArray, "Problem") then
	LogDebug("NCIP Error: ReRouting Transaction");
	ExecuteCommand("Route", {currentTN, Settings.BorrowingCheckInItemFailQueue});
	LogDebug("Adding Note to Transaction with NCIP Client Error");
	ExecuteCommand("AddNote", {currentTN, BCIIresponseArray});
    SaveDataSource("Transaction");

	else
	LogDebug("No Problems found in NCIP Response.")
	ExecuteCommand("AddNote", {currentTN, "NCIP Response for BorrowingCheckInItem received successfully"});
    SaveDataSource("Transaction");
	end
end

--Lending Functions
function LendingCheckOutItem(transactionProcessedEventArgs)
	LogDebug("DEBUG -- LendingCheckOutItem - start");
	luanet.load_assembly("System");
	local ncipAddress = Settings.NCIP_Responder_URL;
	local LCOImessage = buildCheckOutItem();
	LogDebug("creating LendingCheckOutItem message[" .. LCOImessage .. "]");
	local WebClient = luanet.import_type("System.Net.WebClient");
	local myWebClient = WebClient();
	LogDebug("WebClient Created");
	LogDebug("Adding Header");
	myWebClient.Headers:Add("Content-Type", "text/xml; charset=UTF-8");
	LogDebug("Setting Upload String");
	local LCOIresponseArray = myWebClient:UploadString(ncipAddress, LCOImessage);
	LogDebug("Upload response was[" .. LCOIresponseArray .. "]");

	LogDebug("Starting error catch")
	local currentTN = GetFieldValue("Transaction", "TransactionNumber");

	if string.find(LCOIresponseArray, "Apply to circulation desk - Loan cannot be renewed (no change in due date)") then
	LogDebug("NCIP Error: ReRouting Transaction");
	ExecuteCommand("Route", {currentTN, "NCIP Error: LCheckOut-No Change Due Date"});
	LogDebug("Adding Note to Transaction with NCIP Client Error");
	ExecuteCommand("AddNote", {currentTN, LCOIresponseArray});
    SaveDataSource("Transaction");

	elseif string.find(LCOIresponseArray, "User Ineligible To Check Out This Item") then
	LogDebug("NCIP Error: ReRouting Transaction");
	ExecuteCommand("Route", {currentTN, "NCIP Error: LCheckOut-User Ineligible"});
	LogDebug("Adding Note to Transaction with NCIP Client Error");
	ExecuteCommand("AddNote", {currentTN, LCOIresponseArray});
    SaveDataSource("Transaction");

	elseif string.find(LCOIresponseArray, "User Unknown") then
	LogDebug("NCIP Error: ReRouting Transaction");
	ExecuteCommand("Route", {currentTN, "NCIP Error: LCheckOut-User Unknown"});
	LogDebug("Adding Note to Transaction with NCIP Client Error");
	ExecuteCommand("AddNote", {currentTN, LCOIresponseArray});
    SaveDataSource("Transaction");

	elseif string.find(LCOIresponseArray, "Problem") then
	LogDebug("NCIP Error: ReRouting Transaction");
	ExecuteCommand("Route", {currentTN, Settings.LendingCheckOutItemFailQueue});
	LogDebug("Adding Note to Transaction with NCIP Client Error");
	ExecuteCommand("AddNote", {currentTN, LCOIresponseArray});
    SaveDataSource("Transaction");

	else
	LogDebug("No Problems found in NCIP Response.")
	ExecuteCommand("AddNote", {currentTN, "NCIP Response for LendingCheckOutItem received successfully"});
    SaveDataSource("Transaction");
	end
end

function LendingCheckInItem(transactionProcessedEventArgs)
	LogDebug("LendingCheckInItem - start");
	luanet.load_assembly("System");
	local ncipAddress = Settings.NCIP_Responder_URL;
	local LCIImessage = buildCheckInItemLending();
	LogDebug("creating LendingCheckInItem message[" .. LCIImessage .. "]");
	local WebClient = luanet.import_type("System.Net.WebClient");
	local myWebClient = WebClient();
	LogDebug("WebClient Created");
	LogDebug("Adding Header");
	myWebClient.Headers:Add("Content-Type", "text/xml; charset=UTF-8");
	LogDebug("Setting Upload String");
	local LCIIresponseArray = myWebClient:UploadString(ncipAddress, LCIImessage);
	LogDebug("Upload response was[" .. LCIIresponseArray .. "]");

	LogDebug("Starting error catch")
	local currentTN = GetFieldValue("Transaction", "TransactionNumber");

	if string.find(LCIIresponseArray, "Unknown Item") then
	LogDebug("NCIP Error: ReRouting Transaction");
	ExecuteCommand("Route", {currentTN, "NCIP Error: LCheckIn-Unknown Item"});
	LogDebug("Adding Note to Transaction with NCIP Client Error");
	ExecuteCommand("AddNote", {currentTN, LCIIresponseArray});
    SaveDataSource("Transaction");

	elseif string.find(LCIIresponseArray, "Item Not Checked Out") then
	LogDebug("NCIP Error: ReRouting Transaction");
	ExecuteCommand("Route", {currentTN, "NCIP Error: LCheckIn-Not Checked Out"});
	LogDebug("Adding Note to Transaction with NCIP Client Error");
	ExecuteCommand("AddNote", {currentTN, LCIIresponseArray});
    SaveDataSource("Transaction");

	elseif string.find(LCIIresponseArray, "Problem") then
	LogDebug("NCIP Error: ReRouting Transaction");
	ExecuteCommand("Route", {currentTN, Settings.LendingCheckInItemFailQueue});
	LogDebug("Adding Note to Transaction with NCIP Client Error");
	ExecuteCommand("AddNote", {currentTN, LCIIresponseArray});
    SaveDataSource("Transaction");

	else
	LogDebug("No Problems found in NCIP Response.")
	ExecuteCommand("AddNote", {currentTN, "NCIP Response for LendingCheckInItem received successfully"});
    SaveDataSource("Transaction");
	end
end

--AcceptItem XML Builder for Borrowing
--sometimes Author fields and Title fields are blank
function buildAcceptItem()
local tn = "";
local dr = tostring(GetFieldValue("Transaction", "DueDate"));
local df = string.match(dr, "%d+\/%d+\/%d+");
local mn, dy, yr = string.match(df, "(%d+)/(%d+)/(%d+)");
local mnt = string.format("%02d",mn);
local dya = string.format("%02d",dy);
local user = GetFieldValue("Transaction", "Username");
local t = GetFieldValue("Transaction", "TransactionNumber");
if Settings.Use_Prefixes then
	if GetFieldValue("Transaction", "LibraryUseOnly") and GetFieldValue("Transaction", "RenewalsAllowed") then
	    tn = Settings.Prefix_for_LibraryUseOnly_and_RenewablesAllowed .. t;
	end
	if GetFieldValue("Transaction", "LibraryUseOnly") and GetFieldValue("Transaction", "RenewalsAllowed") ~= true then
	    tn = Settings.Prefix_for_LibraryUseOnly .. t;
	end
	if GetFieldValue("Transaction", "RenewalsAllowed") and GetFieldValue("Transaction", "LibraryUseOnly") ~= true then
		tn = Settings.Prefix_for_RenewablesAllowed .. t;
	end
	if GetFieldValue("Transaction", "LibraryUseOnly") ~= true and GetFieldValue("Transaction", "RenewalsAllowed") ~= true then
		tn = Settings.acceptItem_Transaction_Prefix .. t;
	end
else
	tn = Settings.acceptItem_Transaction_Prefix .. GetFieldValue("Transaction", "TransactionNumber");
end

local author = GetFieldValue("Transaction", "LoanAuthor");
	if author == nil then
		author = "";
	end
	if string.find(author, "&") ~= nil then
		author = string.gsub(author, "&", "and");
	end
local title = GetFieldValue("Transaction", "LoanTitle");
	if title == nil then
		title = "";
	end
	if string.find(title, "&") ~= nil then
		title = string.gsub(title, "&", "and");
	end
	
--account for multiple site pickup locations
local templine = nil;
local pickup_location = "";
local pickup_location_full = GetFieldValue("Transaction", "Site");
	if pickup_location_full == "Architecture" then pickup_location = "arch";
	elseif pickup_location_full == "East Asian" then pickup_location = "eastasian";
	elseif pickup_location_full == "Engineering" then pickup_location = "engineer";
 	elseif pickup_location_full == "Firestone" then pickup_location = "firestone";
	elseif pickup_location_full == "Lewis" then pickup_location = "lewis";
	elseif pickup_location_full == "Marquand" then pickup_location = "marquand";
	elseif pickup_location_full == "Music" then pickup_location = "mendel";
	elseif pickup_location_full == "PPL" then pickup_location = "plasma";
	elseif pickup_location_full == "Stokes" then pickup_location = "stokes";
  	else
    	pickup_location =  "EMPTY";
end

local m = '';
    m = m .. '<?xml version="1.0" encoding="ISO-8859-1"?>'
	m = m .. '<NCIPMessage xmlns="http://www.niso.org/2008/ncip" version="http://www.niso.org/schemas/ncip/v2_02/ncip_v2_02.xsd">'
	m = m .. '<AcceptItem>'
	m = m .. '<InitiationHeader>'
	m = m .. '<FromAgencyId>'
	m = m .. '<AgencyId>' .. Settings.acceptItem_from_uniqueAgency_value .. '</AgencyId>'
	m = m .. '</FromAgencyId>'
	m = m .. '<ToAgencyId>'
	m = m .. '<AgencyId>' .. Settings.acceptItem_from_uniqueAgency_value .. '</AgencyId>'
	m = m .. '</ToAgencyId>'
	m = m .. '<ApplicationProfileType>' .. Settings.ApplicationProfileType .. '</ApplicationProfileType>'
	m = m .. '</InitiationHeader>'
	m = m .. '<RequestId>'
	m = m .. '<AgencyId>' .. Settings.acceptItem_from_uniqueAgency_value .. '</AgencyId>'
	m = m .. '<RequestIdentifierValue>' .. tn .. '</RequestIdentifierValue>'
	m = m .. '</RequestId>'
	m = m .. '<RequestedActionType>Hold For Pickup And Notify</RequestedActionType>'
	m = m .. '<UserId>'
	m = m .. '<AgencyId>' .. Settings.acceptItem_from_uniqueAgency_value .. '</AgencyId>'
	m = m .. '<UserIdentifierType>Barcode Id</UserIdentifierType>'
	m = m .. '<UserIdentifierValue>' .. user .. '</UserIdentifierValue>'
	m = m .. '</UserId>'
	m = m .. '<ItemId>'
	m = m .. '<ItemIdentifierValue>' .. t .. '</ItemIdentifierValue>'
	m = m .. '</ItemId>'
	m = m .. '<DateForReturn>' .. yr .. '-' .. mnt .. '-' .. dya .. 'T23:59:00' .. '</DateForReturn>'
--  m = m .. '<PickupLocation>' .. pickup_location .. '</PickupLocation>'
	m = m .. '<ItemOptionalFields>'
	m = m .. '<BibliographicDescription>'
	m = m .. '<Author>' .. author .. '</Author>'
	m = m .. '<Title>' .. title .. '</Title>'
	m = m .. '</BibliographicDescription>'
	m = m .. '</ItemOptionalFields>'
	m = m .. '</AcceptItem>'
	m = m .. '</NCIPMessage>'
	return m;
 end

--ReturnedItem XML Builder for Borrowing (Patron Returns)
function buildCheckInItemBorrowing()
local tn = "";
local t = GetFieldValue("Transaction", "TransactionNumber");
local user = GetFieldValue("Transaction", "Username");
if Settings.Use_Prefixes then
	if GetFieldValue("Transaction", "LibraryUseOnly") and GetFieldValue("Transaction", "RenewalsAllowed") then
	    tn = Settings.Prefix_for_LibraryUseOnly_and_RenewablesAllowed .. t;
	end
	if GetFieldValue("Transaction", "LibraryUseOnly") and GetFieldValue("Transaction", "RenewalsAllowed") ~= true then
	    tn = Settings.Prefix_for_LibraryUseOnly .. t;
	end
	if GetFieldValue("Transaction", "RenewalsAllowed") and GetFieldValue("Transaction", "LibraryUseOnly") ~= true then
		tn = Settings.Prefix_for_RenewablesAllowed .. t;
	end
	if GetFieldValue("Transaction", "LibraryUseOnly") ~= true and GetFieldValue("Transaction", "RenewalsAllowed") ~= true then
		tn = Settings.acceptItem_Transaction_Prefix .. t;
	end
else
	tn = Settings.acceptItem_Transaction_Prefix .. GetFieldValue("Transaction", "TransactionNumber");
end

local cib = '';
    cib = cib .. '<?xml version="1.0" encoding="ISO-8859-1"?>'
	cib = cib .. '<NCIPMessage xmlns="http://www.niso.org/2008/ncip" version="http://www.niso.org/schemas/ncip/v2_02/ncip_v2_02.xsd">'
	cib = cib .. '<CheckInItem>'
	cib = cib .. '<InitiationHeader>'
	cib = cib .. '<FromAgencyId>'
	cib = cib .. '<AgencyId>' .. Settings.acceptItem_from_uniqueAgency_value .. '</AgencyId>'
	cib = cib .. '</FromAgencyId>'
	cib = cib .. '<ToAgencyId>'
	cib = cib .. '<AgencyId>' .. Settings.acceptItem_from_uniqueAgency_value .. '</AgencyId>'
	cib = cib .. '</ToAgencyId>'
	cib = cib .. '<ApplicationProfileType>' .. Settings.ApplicationProfileType .. '</ApplicationProfileType>'
	cib = cib .. '</InitiationHeader>'
	cib = cib .. '<UserId>'
	cib = cib .. '<UserIdentifierValue>' .. user .. '</UserIdentifierValue>'
	cib = cib .. '</UserId>'
	cib = cib .. '<ItemId>'
	cib = cib .. '<AgencyId>' .. Settings.acceptItem_from_uniqueAgency_value .. '</AgencyId>'
	cib = cib .. '<ItemIdentifierValue>' .. t .. '</ItemIdentifierValue>'
	cib = cib .. '</ItemId>'
	cib = cib .. '<RequestId>'
	cib = cib .. '<AgencyId>' .. Settings.acceptItem_from_uniqueAgency_value .. '</AgencyId>'
	cib = cib .. '<RequestIdentifierValue>' .. tn .. '</RequestIdentifierValue>'
	cib = cib .. '</RequestId>'
	cib = cib .. '</CheckInItem>'
	cib = cib .. '</NCIPMessage>'
	return cib;
end

--ReturnedItem XML Builder for Lending (Library Returns)
function buildCheckInItemLending()
local ttype = "";
local user = GetFieldValue("Transaction", "Username");
local itemnumber = GetFieldValue("Transaction", "ItemNumber");
local trantype = GetFieldValue("Transaction", "ProcessType");
	if trantype == "Borrowing" then
		ttype = Settings.checkInItem_Transaction_Prefix .. GetFieldValue("Transaction", "TransactionNumber");
	elseif trantype == "Lending" then
		ttype = GetFieldValue("Transaction", "ItemNumber");
	else
		ttype = Settings.checkInItem_Transaction_Prefix .. GetFieldValue("Transaction", "TransactionNumber");
	end

local cil = '';
    cil = cil .. '<?xml version="1.0" encoding="ISO-8859-1"?>'
	cil = cil .. '<NCIPMessage xmlns="http://www.niso.org/2008/ncip" version="http://www.niso.org/schemas/ncip/v2_02/ncip_v2_02.xsd">'
	cil = cil .. '<CheckInItem>'
	cil = cil .. '<InitiationHeader>'
	cil = cil .. '<FromAgencyId>'
	cil = cil .. '<AgencyId>' .. Settings.acceptItem_from_uniqueAgency_value .. '</AgencyId>'
	cil = cil .. '</FromAgencyId>'
	cil = cil .. '<ToAgencyId>'
	cil = cil .. '<AgencyId>' .. Settings.acceptItem_from_uniqueAgency_value .. '</AgencyId>'
	cil = cil .. '</ToAgencyId>'
	cil = cil .. '<ApplicationProfileType>' .. Settings.ApplicationProfileType .. '</ApplicationProfileType>'
	cil = cil .. '</InitiationHeader>'
	cil = cil .. '<UserId>'
	cil = cil .. '<UserIdentifierValue>' .. user .. '</UserIdentifierValue>'
	cil = cil .. '</UserId>'
	cil = cil .. '<ItemId>'
	cil = cil .. '<AgencyId>' .. Settings.acceptItem_from_uniqueAgency_value .. '</AgencyId>'
	cil = cil .. '<ItemIdentifierValue>' .. itemnumber .. '</ItemIdentifierValue>'
	cil = cil .. '</ItemId>'
	cil = cil .. '<RequestId>'
	cil = cil .. '<AgencyId>' .. Settings.acceptItem_from_uniqueAgency_value .. '</AgencyId>'
	cil = cil .. '<RequestIdentifierValue>' .. ttype .. '</RequestIdentifierValue>'
	cil = cil .. '</RequestId>'
	cil = cil .. '</CheckInItem>'
	cil = cil .. '</NCIPMessage>'
	return cil;
end

--CheckOutItem XML Builder for Lending
function buildCheckOutItem()
local dr = tostring(GetFieldValue("Transaction", "DueDate"));
local df = string.match(dr, "%d+\/%d+\/%d+");
local mn, dy, yr = string.match(df, "(%d+)/(%d+)/(%d+)");
local mnt = string.format("%02d",mn);
local dya = string.format("%02d",dy);
local pseudopatron = 'pseudopatron';
local itemnumber = GetFieldValue("Transaction", "ItemNumber");
local tn = Settings.checkOutItem_RequestIdentifierValue_Prefix .. GetFieldValue("Transaction", "TransactionNumber");
local coi = '';
    coi = coi .. '<?xml version="1.0" encoding="ISO-8859-1"?>'
	coi = coi .. '<NCIPMessage xmlns="http://www.niso.org/2008/ncip" version="http://www.niso.org/schemas/ncip/v2_02/ncip_v2_02.xsd">'
	coi = coi .. '<CheckOutItem>'
	coi = coi .. '<InitiationHeader>'
	coi = coi .. '<FromAgencyId>'
	coi = coi .. '<AgencyId>' .. Settings.acceptItem_from_uniqueAgency_value .. '</AgencyId>'
	coi = coi .. '</FromAgencyId>'
	coi = coi .. '<ToAgencyId>'
	coi = coi .. '<AgencyId>' .. Settings.acceptItem_from_uniqueAgency_value .. '</AgencyId>'
	coi = coi .. '</ToAgencyId>'
	coi = coi .. '<ApplicationProfileType>' .. Settings.ApplicationProfileType .. '</ApplicationProfileType>'
	coi = coi .. '</InitiationHeader>'
	coi = coi .. '<UserId>'
	coi = coi .. '<UserIdentifierValue>' .. pseudopatron .. '</UserIdentifierValue>'
	coi = coi .. '</UserId>'
	coi = coi .. '<ItemId>'
	coi = coi .. '<AgencyId>' .. Settings.acceptItem_from_uniqueAgency_value .. '</AgencyId>'
	coi = coi .. '<ItemIdentifierValue>' .. itemnumber .. '</ItemIdentifierValue>'
	coi = coi .. '</ItemId>'
	coi = coi .. '<RequestId>'
	coi = coi .. '<AgencyId>' .. Settings.acceptItem_from_uniqueAgency_value .. '</AgencyId>'
	coi = coi .. '<RequestIdentifierValue>' .. tn .. '</RequestIdentifierValue>'
	coi = coi .. '</RequestId>'
	coi = coi .. '<DesiredDateDue>' .. yr .. '-' .. mnt .. '-' .. dya .. 'T23:59:00' .. '</DesiredDateDue>'
	coi = coi .. '</CheckOutItem>'
	coi = coi .. '</NCIPMessage>'
	return coi;

end