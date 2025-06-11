<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Cryonix - Channels</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
    <link href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css" rel="stylesheet">
    <link rel="stylesheet" href="/assets/css/style.css">
</head>
<body>
    <?php include 'includes/navbar.php'; ?>
    
    <div class="container-fluid">
        <div class="row">
            <?php include 'includes/sidebar.php'; ?>
            
            <main class="col-md-9 ms-sm-auto col-lg-10 px-md-4">
                <div class="d-flex justify-content-between flex-wrap flex-md-nowrap align-items-center pt-3 pb-2 mb-3 border-bottom">
                    <h1 class="h2">Channels Management</h1>
                    <div class="btn-toolbar mb-2 mb-md-0">
                        <button class="btn btn-primary" id="addChannelBtn">
                            <i class="fas fa-plus"></i> Add Channel
                        </button>
                    </div>
                </div>
                
                <div class="row mb-3">
                    <div class="col-md-6">
                        <input type="text" class="form-control" id="searchChannels" placeholder="Search channels...">
                    </div>
                    <div class="col-md-3">
                        <select class="form-select" id="categoryFilter">
                            <option value="">All Categories</option>
                            <option value="sports">Sports</option>
                            <option value="news">News</option>
                            <option value="entertainment">Entertainment</option>
                            <option value="movies">Movies</option>
                        </select>
                    </div>
                    <div class="col-md-3">
                        <select class="form-select" id="statusFilter">
                            <option value="">All Status</option>
                            <option value="active">Active</option>
                            <option value="inactive">Inactive</option>
                        </select>
                    </div>
                </div>
                
                <div class="row" id="channelsContainer">
                    <?php
                    $channels = getChannels();
                    foreach ($channels as $channel):
                    ?>
                    <div class="col-md-6 col-lg-4 mb-4">
                        <div class="card h-100">
                            <div class="card-body">
                                <div class="d-flex justify-content-between align-items-start mb-2">
                                    <h5 class="card-title"><?= htmlspecialchars($channel['name']) ?></h5>
                                    <span class="badge bg-<?= $channel['status'] === 'active' ? 'success' : 'secondary' ?>">
                                        <?= ucfirst($channel['status']) ?>
                                    </span>
                                </div>
                                <p class="card-text text-muted"><?= htmlspecialchars($channel['category'] ?: 'No category') ?></p>
                                <p class="card-text"><small class="text-muted"><?= htmlspecialchars($channel['stream_url']) ?></small></p>
                                <div class="d-flex justify-content-between">
                                    <button class="btn btn-sm btn-outline-primary edit-channel-btn" data-channel-id="<?= $channel['id'] ?>">
                                        <i class="fas fa-edit"></i> Edit
                                    </button>
                                    <button class="btn btn-sm btn-outline-success start-stream-btn" data-channel-id="<?= $channel['id'] ?>">
                                        <i class="fas fa-play"></i> Start
                                    </button>
                                    <button class="btn btn-sm btn-outline-danger delete-channel-btn" data-channel-id="<?= $channel['id'] ?>">
                                        <i class="fas fa-trash"></i> Delete
                                    </button>
                                </div>
                            </div>
                        </div>
                    </div>
                    <?php endforeach; ?>
                </div>
            </main>
        </div>
    </div>
    
    <!-- Add Channel Modal -->
    <div class="modal fade" id="addChannelModal" tabindex="-1">
        <div class="modal-dialog">
            <div class="modal-content">
                <div class="modal-header">
                    <h5 class="modal-title">Add New Channel</h5>
                    <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                </div>
                <form id="addChannelForm">
                    <div class="modal-body">
                        <div class="mb-3">
                            <label for="channelName" class="form-label">Channel Name</label>
                            <input type="text" class="form-control" id="channelName" name="name" required>
                        </div>
                        <div class="mb-3">
                            <label for="streamUrl" class="form-label">Stream URL</label>
                            <input type="url" class="form-control" id="streamUrl" name="stream_url" required>
                        </div>
                        <div class="mb-3">
                            <label for="category" class="form-label">Category</label>
                            <select class="form-select" id="category" name="category">
                                <option value="">Select Category</option>
                                <option value="sports">Sports</option>
                                <option value="news">News</option>
                                <option value="entertainment">Entertainment</option>
                                <option value="movies">Movies</option>
                            </select>
                        </div>
                        <div class="mb-3">
                            <label for="logoUrl" class="form-label">Logo URL</label>
                            <input type="url" class="form-control" id="logoUrl" name="logo_url">
                        </div>
                    </div>
                    <div class="modal-footer">
                        <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancel</button>
                        <button type="submit" class="btn btn-primary">Add Channel</button>
                    </div>
                </form>
            </div>
        </div>
    </div>
    
    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js"></script>
    <script src="/assets/js/app.js"></script>
</body>
</html>
