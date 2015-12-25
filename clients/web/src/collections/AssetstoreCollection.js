/**
 * @class
 * @extends girder.Collection
 */
girder.collections.AssetstoreCollection = girder.Collection.extend(
    /** @lends girder.collections.AssetstoreCollection.prototype */
    {
        resourceName: 'assetstore',
        model: girder.models.AssetstoreModel
    }
);
