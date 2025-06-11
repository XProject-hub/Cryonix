<!-- File: web/resources/views/users/index.blade.php -->
@extends('layouts.app')

@section('title', 'Users Management')
@section('page-title', 'Users')

@section('content')
<div class="row mb-3">
    <div class="col-md-6">
        <div class="input-group">
            <input type="text" class="form-control" placeholder="Search users..." id="searchInput">
            <button class="btn btn-outline-secondary" type="button">
                <i class="bi bi-search"></i>
            </button>
        </div>
    </div>
    <div class="col-md-6 text-end">
        <a href="{{ route('users.create') }}" class="btn btn-primary">
            <i class="bi bi-plus"></i> Add User
        </a>
    </div>
</div>

<div class="card shadow">
    <div class="card-header">
        <h6 class="m-0 font-weight-bold text-primary">Users List</h6>
    </div>
    <div class="card-body">
        <div class="table-responsive">
            <table class="table table-hover">
                <thead>
                    <tr>
                        <th>Username</th>
                        <th>Email</th>
                        <th>Role</th>
                        <th>Status</th>
                        <th>Created</th>
                        <th>Actions</th>
                    </tr>
                </thead>
                <tbody>
                    @foreach($users as $user)
                    <tr>
                        <td>{{ $user->username }}</td>
                        <td>{{ $user->email }}</td>
                        <td><span class="badge bg-info">{{ ucfirst($user->role) }}</span></td>
                        <td>
                            @if($user->is_active)
                                <span class="badge bg-success">Active</span>
                            @else
                                <span class="badge bg-danger">Inactive</span>
                            @endif
                        </td>
                        <td>{{ $user->created_at->format('M d, Y') }}</td>
                        <td>
                            <div class="btn-group btn-group-sm">
                                <a href="{{ route('users.edit', $user) }}" class="btn btn-outline-warning">
                                    <i class="bi bi-pencil"></i>
                                </a>
                                <button class="btn btn-outline-danger" onclick="deleteUser({{ $user->id }})">
                                    <i class="bi bi-trash"></i>
                                </button>
                            </div>
                        </td>
                    </tr>
                    @endforeach
                </tbody>
            </table>
        </div>
        {{ $users->links() }}
    </div>
</div>
@endsection
