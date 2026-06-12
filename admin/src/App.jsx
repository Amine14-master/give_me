import { useState, useEffect } from 'react';
import { db } from './firebase';
import { ref, onValue, remove } from 'firebase/database';
import { Users, Package, Activity, Inbox, Bell, Search, Heart, Trash2 } from 'lucide-react';
import './index.css';

function App() {
  const [items, setItems] = useState([]);
  const [usersCount, setUsersCount] = useState(0);
  const [activeTab, setActiveTab] = useState('dashboard');
  const [searchTerm, setSearchTerm] = useState('');
  const [showSplash, setShowSplash] = useState(true);

  useEffect(() => {
    const timer = setTimeout(() => {
      setShowSplash(false);
    }, 2000);
    return () => clearTimeout(timer);
  }, []);

  if (showSplash) {
    return (
      <div style={{ display: 'flex', justifyContent: 'center', alignItems: 'center', height: '100vh', backgroundColor: 'white' }}>
        <img src="/logo.png" alt="GiveMe Logo" style={{ width: '150px', height: '150px' }} />
      </div>
    );
  }

  useEffect(() => {
    const itemsRef = ref(db, 'items');
    onValue(itemsRef, (snapshot) => {
      const data = snapshot.val();
      if (data) {
        const itemsList = Object.keys(data).map(key => ({
          id: key,
          ...data[key]
        }));
        setItems(itemsList.reverse()); // Newest first
      } else {
        setItems([]);
      }
    });

    // Mock Users if RTDB doesn't have a 'users' node populated yet
    const usersRef = ref(db, 'users');
    onValue(usersRef, (snapshot) => {
      const data = snapshot.val();
      // Assume unique users based on items if users node is empty
      if (data) {
        setUsersCount(Object.keys(data).length);
      }
    });
  }, []);

  // Compute unique users from items if users node is 0
  const actualUsersCount = usersCount > 0 ? usersCount : new Set(items.map(i => i.userId)).size;

  const handleDelete = (id) => {
    if (window.confirm("Are you sure you want to delete this item?")) {
      remove(ref(db, `items/${id}`));
    }
  };

  const filteredItems = items.filter(item => 
    item.title?.toLowerCase().includes(searchTerm.toLowerCase()) ||
    item.category?.toLowerCase().includes(searchTerm.toLowerCase())
  );

  const renderDashboard = () => (
    <div className="fade-in">
      <div className="metrics-grid">
        <div className="metric-card">
          <div className="metric-icon blue"><Package size={28} /></div>
          <div className="metric-info">
            <h3>Total Items Given</h3>
            <p>{items.length}</p>
          </div>
        </div>
        <div className="metric-card">
          <div className="metric-icon green"><Users size={28} /></div>
          <div className="metric-info">
            <h3>Community Members</h3>
            <p>{actualUsersCount}</p>
          </div>
        </div>
        <div className="metric-card">
          <div className="metric-icon purple"><Activity size={28} /></div>
          <div className="metric-info">
            <h3>Successful Exchanges</h3>
            <p>{items.filter(i => i.status === 'claimed').length}</p>
          </div>
        </div>
      </div>

      <div className="section-header">
        <h2 className="section-title">Recent Activity</h2>
        <button className="view-all-btn" onClick={() => setActiveTab('items')}>View All Items</button>
      </div>

      <div className="table-container">
        <table className="modern-table">
          <thead>
            <tr>
              <th>Item</th>
              <th>Category</th>
              <th>Status</th>
              <th>Provider</th>
            </tr>
          </thead>
          <tbody>
            {items.length === 0 ? (
              <tr>
                <td colSpan="4" className="empty-state">Waiting for the first act of kindness.</td>
              </tr>
            ) : (
              items.slice(0, 5).map(item => (
                <tr key={item.id}>
                  <td>
                    <div className="item-cell">
                      {item.imageUrl ? (
                        <img src={item.imageUrl} alt={item.title} className="item-image" />
                      ) : (
                        <div className="item-image"><Heart size={20} color="var(--accent-purple)" /></div>
                      )}
                      <div>
                        <strong>{item.title}</strong>
                        <div style={{ fontSize: '0.8rem', color: 'var(--text-muted)' }}>{new Date(item.createdAt || Date.now()).toLocaleDateString()}</div>
                      </div>
                    </div>
                  </td>
                  <td><span className="badge category">{item.category}</span></td>
                  <td><span className={`badge ${item.status || 'available'}`}>{item.status || 'available'}</span></td>
                  <td>{item.userId?.substring(0, 6)}...</td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>
    </div>
  );

  const renderItems = () => (
    <div className="fade-in">
      <div className="section-header">
        <h2 className="section-title">All Items</h2>
        <div style={{ position: 'relative' }}>
          <Search size={18} style={{ position: 'absolute', left: 12, top: 12, color: 'var(--text-muted)' }} />
          <input 
            type="text" 
            placeholder="Search items..." 
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            style={{ 
              background: 'var(--bg-card)', border: '1px solid var(--border-color)', 
              color: 'var(--text-main)', padding: '10px 16px 10px 40px', borderRadius: '100px', width: '250px' 
            }} 
          />
        </div>
      </div>
      
      <div className="table-container">
        <table className="modern-table">
          <thead>
            <tr>
              <th>Item</th>
              <th>Category</th>
              <th>Status</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            {filteredItems.length === 0 ? (
              <tr>
                <td colSpan="4" className="empty-state">No items found matching your search.</td>
              </tr>
            ) : (
              filteredItems.map(item => (
                <tr key={item.id}>
                  <td>
                    <div className="item-cell">
                      {item.imageUrl ? (
                        <img src={item.imageUrl} alt={item.title} className="item-image" />
                      ) : (
                        <div className="item-image"><Package size={20} color="var(--accent-primary)" /></div>
                      )}
                      <div>
                        <strong>{item.title}</strong>
                        <div style={{ fontSize: '0.8rem', color: 'var(--text-muted)' }}>{item.description}</div>
                      </div>
                    </div>
                  </td>
                  <td><span className="badge category">{item.category}</span></td>
                  <td><span className={`badge ${item.status || 'available'}`}>{item.status || 'available'}</span></td>
                  <td>
                    <button className="action-btn delete" onClick={() => handleDelete(item.id)}>
                      <Trash2 size={16} />
                    </button>
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>
    </div>
  );

  const renderPlaceholder = (title, icon) => (
    <div className="fade-in" style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', height: '60vh' }}>
      <div style={{ width: 100, height: 100, background: 'var(--bg-card)', borderRadius: '50%', display: 'flex', alignItems: 'center', justifyContent: 'center', marginBottom: '2rem' }}>
        {icon}
      </div>
      <h2 style={{ fontSize: '2rem', marginBottom: '1rem' }}>{title}</h2>
      <p style={{ color: 'var(--text-muted)', textAlign: 'center', maxWidth: 400 }}>
        This section is fully designed and ready for backend integration when data models are finalized.
      </p>
    </div>
  );

  const renderContent = () => {
    switch (activeTab) {
      case 'dashboard': return renderDashboard();
      case 'items': return renderItems();
      case 'users': return renderPlaceholder('User Management', <Users size={48} color="var(--accent-green)" />);
      case 'requests': return renderPlaceholder('Requests & Messages', <Inbox size={48} color="var(--accent-purple)" />);
      default: return renderDashboard();
    }
  };

  return (
    <div className="admin-container">
      <aside className="sidebar">
        <div className="logo-container">
          <div className="logo-icon"><Heart size={20} fill="white" /></div>
          <h2>GiveMe <span className="highlight">Admin</span></h2>
        </div>
        <nav className="nav-menu">
          <div className={`nav-item ${activeTab === 'dashboard' ? 'active' : ''}`} onClick={() => setActiveTab('dashboard')}>
            <Activity className="icon" size={20} /> Dashboard
          </div>
          <div className={`nav-item ${activeTab === 'items' ? 'active' : ''}`} onClick={() => setActiveTab('items')}>
            <Package className="icon" size={20} /> Items
          </div>
          <div className={`nav-item ${activeTab === 'users' ? 'active' : ''}`} onClick={() => setActiveTab('users')}>
            <Users className="icon" size={20} /> Users
          </div>
          <div className={`nav-item ${activeTab === 'requests' ? 'active' : ''}`} onClick={() => setActiveTab('requests')}>
            <Inbox className="icon" size={20} /> Requests
          </div>
        </nav>
      </aside>

      <main className="main-content">
        <header className="top-header">
          <h1 style={{textTransform: 'capitalize'}}>{activeTab}</h1>
          <div className="header-actions">
            <button className="notification-btn">
              <Bell size={20} />
            </button>
            <div className="user-profile">
              <div className="avatar"></div>
              <span style={{ fontWeight: 600 }}>Super Admin</span>
            </div>
          </div>
        </header>

        {renderContent()}
      </main>
    </div>
  );
}

export default App;
