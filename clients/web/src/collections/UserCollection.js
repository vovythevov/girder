/*
 * @class
 * @extends girder.Collection
 */
girder.collections.UserCollection = girder.Collection.extend(
    /** @lends girder.collections.UserCollection.prototype */
    {
        resourceName: 'user',
        model: girder.models.UserModel,

        // Override default sort field
        sortField: 'lastName',
        secondarySortField: 'firstName'
    }
);
