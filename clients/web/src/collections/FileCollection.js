/*
 * @class
 * @extends girder.Collection
 */
girder.collections.FileCollection = girder.Collection.extend(
    /** @lends girder.collections.FileCollection.prototype */
    {
        resourceName: 'file',

        model: girder.models.FileModel,

        pageLimit: 100
    }
);
