/*
 * @class
 * @extends girder.Collection
 */
girder.collections.GroupCollection = girder.Collection.extend(
    /** @lends girder.collections.GroupCollection.prototype */
    {
        resourceName: 'group',
        model: girder.models.GroupModel

    }
);
