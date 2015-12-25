/**
 * @class
 * @extends girder.Collection
 */
girder.collections.FolderCollection = girder.Collection.extend(
    /** @lends girdder.collections.FolderCollection.prototype */
    {
        resourceName: 'folder',
        model: girder.models.FolderModel,

        pageLimit: 100
    }
);
