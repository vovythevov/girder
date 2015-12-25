/*
 * @class
 * @extends girder.Collection
 */
girder.collections.ItemCollection = girder.Collection.extend(
    /** @lends girder.collections.ItemCollection.prototype */
    {
        resourceName: 'item',
        model: girder.models.ItemModel,

        pageLimit: 100
    }
);
