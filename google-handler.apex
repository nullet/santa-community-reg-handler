global class PlatformGoogleRegHandler implements Auth.RegistrationHandler{

    private static final String ORG_SUFFIX = '.giftexchange.platform';

    /**
    * Let anyone register as long as the required fields are supplied
    * 
    * We require email, lastName, firstName
    * 
    * @data - the user's info from the Auth Provider
    **/
    global boolean canCreateUser(Auth.UserData data) {
        System.debug('canCreateUser was called for ' + (data != null ? data.email : 'null'));
        Boolean returnVal = (data != null
                    && data.email != null
                    && data.lastName != null
                    && data.firstName != null);

        System.debug('data.username='+data.username);
        System.debug('data.email='+data.email);
        System.debug('data.lastName='+data.lastName);
        System.debug('data.firstName='+data.firstName);

        return returnVal;

    }

    /**
    * Create the User - A required method to implement the Handler Interface
    * 
    * @param portalId  - Id of the Community
    * @param data - Auth Provider user data describing the User to create
    * 
    * @return User that has been initialized
    **/
    global User createUser(Id portalId, Auth.UserData data){
        if(!canCreateUser(data)) {
            // Returning null signals the auth framework that we can't create the user
            return null;
        }

        // Is this a Community context?
        if(data.attributeMap.containsKey('sfdc_networkid')) {
            System.debug('Registering Community user: ' + data.email);

            // create PersonAccount in a separate method
            Id contactId = createPersonAccountContact(data);

            Profile p = [SELECT Id FROM profile WHERE name='Gift Exchange Community User'];

            // init user in another method #modularity
            User newUser = createUser(data, p);

            newUser.contactId = contactId;
            return newUser;
        } else {
            // this is not within a community, therefore we assign an internal profile
            Profile p = [SELECT Id FROM profile WHERE name='Standard User'];

            // init user in another method #modularity
            User newUser = createUser(data, p);

            return newUser;
        }
    }

    /**
    * Update the user
    * @param portalId  - Id of the Community
    * @param data - Auth Provider user data describing the User to create
    **/
    global void updateUser(Id userId, Id portalId, Auth.UserData data){
        System.debug('Update User called for: ' + data.email);

        User u = new User(id=userId);
        u.email = data.email;
        u.lastName = data.lastName;
        u.firstName = data.firstName;
        update(u);
    }
    /**
     * Create a PersonAccount for the contact
     * 
     * @param data - Google provided context for this User
     **/
    private Id createPersonAccountContact(Auth.UserData data) {
        Account person = new Account();
        person.LastName = data.lastName;
        person.Firstname = data.firstName;
        person.personEmail = data.email;
        person.RecordTypeId = [SELECT Id FROM RecordType
                                WHERE SobjectType='Account'
                                AND isPersonType=true LIMIT 1].id;
        
        insert person;

        System.debug('Person Account created for ' + data.email + ' id=' + person.id);

        /**
         * This next step is necessary to get a valid contact Id,
         * it won't exist until the PersonAcct is saved
         **/         
        Account a = [Select PersonContactId From Account Where Id = :person.Id];

        return a.PersonContactId;
    }

    /**
    * Create and initialize the User but don't save it yet
    * 
    * @param data - the provided User context from Google
    * @param p - the Profile we are going to assign to this user
    * 
    * @return User that has been initialized but not Saved
    **/
    private User createUser(Auth.UserData data, Profile p) {
        User newUser = new User();
        newUser.username = data.email + ORG_SUFFIX;
        newUser.email = data.email;
        newUser.lastName = data.lastName;
        newUser.firstName = data.firstName;
        String alias = data.firstname.toLowerCase() + data.lastname.toLowerCase();

        //Alias must be 8 characters or less
        if(alias.length() > 8) {
            alias = alias.substring(0, 8);
        }
        newUser.alias = alias;
        newUser.languagelocalekey = UserInfo.getLocale();
        newUser.localesidkey = UserInfo.getLocale();
        newUser.emailEncodingKey = 'UTF-8';
        newUser.timeZoneSidKey = 'America/Los_Angeles';
        newUser.profileId = p.Id;
        return newUser;
    }
}
