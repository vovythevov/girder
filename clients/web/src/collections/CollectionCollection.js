/**
 * @class
 * @extends girder.Collection
 */
girder.collections.CollectionCollection = girder.Collection.extend(
    /** @lends girder.collections.CollectionCollection.prototype */
    {
        resourceName: 'collection',
        model: girder.models.CollectionModel
    }
);
