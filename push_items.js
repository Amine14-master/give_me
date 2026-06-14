const https = require('https');

const dbUrl = 'https://giveme-5e950-default-rtdb.firebaseio.com/items.json';

const items = [
  {
    userId: '+213553776497',
    title: 'Vintage Leather Sofa',
    description: 'A beautifully aged leather sofa in great condition. Need it gone by this weekend.',
    category: 'Furniture',
    location: 'Bab Ezzouar, Algiers',
    lat: 36.7214,
    lng: 3.1858,
    status: 'available',
    timestamp: Date.now(),
    imageUrl: 'https://images.unsplash.com/photo-1555041469-a586c61ea9bc?auto=format&fit=crop&q=80&w=800'
  },
  {
    userId: '+213553776497',
    title: 'Acoustic Guitar Yamaha',
    description: 'Old Yamaha acoustic guitar. Missing one string but sounds great.',
    category: 'Books & Media',
    location: 'Caroubier, Algiers',
    lat: 36.7455,
    lng: 3.1090,
    status: 'available',
    timestamp: Date.now() - 10000,
    imageUrl: 'https://images.unsplash.com/photo-1550291652-6ea9114a47b1?auto=format&fit=crop&q=80&w=800'
  },
  {
    userId: '+213553776497',
    title: 'Winter Jacket (Men M)',
    description: 'Warm winter jacket, barely worn. Fits size medium.',
    category: 'Clothes',
    location: 'Hydra, Algiers',
    lat: 36.7388,
    lng: 3.0336,
    status: 'available',
    timestamp: Date.now() - 20000,
    imageUrl: 'https://images.unsplash.com/photo-1551028719-00167b16eac5?auto=format&fit=crop&q=80&w=800'
  },
  {
    userId: '+213553776497',
    title: 'Box of Fresh Apples',
    description: 'We bought too many apples from the market. Fresh and sweet.',
    category: 'Food',
    location: 'Bab Ezzouar, Algiers',
    lat: 36.7220,
    lng: 3.1860,
    status: 'available',
    timestamp: Date.now() - 30000,
    imageUrl: 'https://images.unsplash.com/photo-1560806887-1e4cd0b6fd6c?auto=format&fit=crop&q=80&w=800'
  },
  {
    userId: '+213553776497',
    title: 'Collection of Sci-Fi Books',
    description: '10 classic science fiction novels. Great condition.',
    category: 'Books & Media',
    location: 'El Biar, Algiers',
    lat: 36.7629,
    lng: 3.0306,
    status: 'available',
    timestamp: Date.now() - 40000,
    imageUrl: 'https://images.unsplash.com/photo-1524578971911-37d4fdf8dbf1?auto=format&fit=crop&q=80&w=800'
  },
  {
    userId: '+213553776497',
    title: 'Samsung 1080p Monitor',
    description: '24-inch monitor, works perfectly. Upgrading to 4K.',
    category: 'Electronics',
    location: 'Zeralda, Algiers',
    lat: 36.7118,
    lng: 2.8427,
    status: 'available',
    timestamp: Date.now() - 50000,
    imageUrl: 'https://images.unsplash.com/photo-1527443154391-507e9dc6c5cc?auto=format&fit=crop&q=80&w=800'
  },
  {
    userId: '+213553776497',
    title: 'Set of Kitchen Plates',
    description: '6 white ceramic plates. No chips or cracks.',
    category: 'Other',
    location: 'Kouba, Algiers',
    lat: 36.7297,
    lng: 3.0881,
    status: 'available',
    timestamp: Date.now() - 60000,
    imageUrl: 'https://images.unsplash.com/photo-1617191778939-5e7e0e8e4530?auto=format&fit=crop&q=80&w=800'
  },
  {
    userId: '+213553776497',
    title: 'Kids Bicycle (Age 5-8)',
    description: 'Red bicycle, needs a little cleaning but runs smooth.',
    category: 'Toys',
    location: 'Caroubier, Algiers',
    lat: 36.7450,
    lng: 3.1095,
    status: 'available',
    timestamp: Date.now() - 70000,
    imageUrl: 'https://images.unsplash.com/photo-1485965120184-e220f721d03e?auto=format&fit=crop&q=80&w=800'
  },
  {
    userId: '+213553776497',
    title: 'Homemade Couscous (2kg)',
    description: 'Extra couscous from family dinner, completely untouched and sealed in a container.',
    category: 'Food',
    location: 'Bab Ezzouar, Algiers',
    lat: 36.7180,
    lng: 3.1800,
    status: 'available',
    timestamp: Date.now() - 80000,
    imageUrl: 'https://images.unsplash.com/photo-1585937421612-70a008356fbe?auto=format&fit=crop&q=80&w=800'
  },
  {
    userId: '+213553776497',
    title: 'Office Chair',
    description: 'Black mesh office chair. Ergonomic and comfortable.',
    category: 'Furniture',
    location: 'Hydra, Algiers',
    lat: 36.7410,
    lng: 3.0310,
    status: 'available',
    timestamp: Date.now() - 90000,
    imageUrl: 'https://images.unsplash.com/photo-1505843490538-5133c6c7d0e1?auto=format&fit=crop&q=80&w=800'
  },
  // Adding 20 more distinct items
  {
    userId: '+213553776497',
    title: 'Baby Stroller',
    description: 'Used for a year. Folds easily.',
    category: 'Toys',
    location: 'Cheraga, Algiers',
    lat: 36.7645,
    lng: 2.9566,
    status: 'available',
    timestamp: Date.now() - 100000,
    imageUrl: 'https://images.unsplash.com/photo-1512438258385-2e1f5abef653?auto=format&fit=crop&q=80&w=800'
  },
  {
    userId: '+213553776497',
    title: 'Coffee Maker',
    description: 'Filter coffee machine. Works great.',
    category: 'Electronics',
    location: 'Bir Mourad Rais, Algiers',
    lat: 36.7328,
    lng: 3.0478,
    status: 'available',
    timestamp: Date.now() - 110000,
    imageUrl: 'https://images.unsplash.com/photo-1497935586351-b67a49e012bf?auto=format&fit=crop&q=80&w=800'
  },
  {
    userId: '+213553776497',
    title: 'Women\'s Running Shoes',
    description: 'Size 38. Used only twice.',
    category: 'Clothes',
    location: 'El Harrach, Algiers',
    lat: 36.7167,
    lng: 3.1333,
    status: 'available',
    timestamp: Date.now() - 120000,
    imageUrl: 'https://images.unsplash.com/photo-1542291026-7eec264c27ff?auto=format&fit=crop&q=80&w=800'
  },
  {
    userId: '+213553776497',
    title: 'Large Wall Mirror',
    description: 'Beautiful wooden frame mirror. 1.5m tall.',
    category: 'Furniture',
    location: 'Bab Ezzouar, Algiers',
    lat: 36.7214,
    lng: 3.1858,
    status: 'available',
    timestamp: Date.now() - 130000,
    imageUrl: 'https://images.unsplash.com/photo-1618220179428-22790b46a011?auto=format&fit=crop&q=80&w=800'
  },
  {
    userId: '+213553776497',
    title: 'Dog Bed (Large)',
    description: 'Cleaned and washed. Too big for our new puppy.',
    category: 'Other',
    location: 'Kouba, Algiers',
    lat: 36.7297,
    lng: 3.0881,
    status: 'available',
    timestamp: Date.now() - 140000,
    imageUrl: 'https://images.unsplash.com/photo-1541781774459-bb2af2f05b55?auto=format&fit=crop&q=80&w=800'
  },
  {
    userId: '+213553776497',
    title: 'Pack of Pasta (Unopened)',
    description: 'Bought in bulk, giving away some.',
    category: 'Food',
    location: 'Sidi Yahia, Algiers',
    lat: 36.7450,
    lng: 3.0300,
    status: 'available',
    timestamp: Date.now() - 150000,
    imageUrl: 'https://images.unsplash.com/photo-1551462147-1f4bb2bb9824?auto=format&fit=crop&q=80&w=800'
  },
  {
    userId: '+213553776497',
    title: 'Math Textbooks',
    description: 'University level Calculus books.',
    category: 'Books & Media',
    location: 'Bab Ezzouar, Algiers',
    lat: 36.7150,
    lng: 3.1900,
    status: 'available',
    timestamp: Date.now() - 160000,
    imageUrl: 'https://images.unsplash.com/photo-1532012197267-da84d127e765?auto=format&fit=crop&q=80&w=800'
  },
  {
    userId: '+213553776497',
    title: 'Old PlayStation 3',
    description: 'Works, comes with 1 controller.',
    category: 'Electronics',
    location: 'Caroubier, Algiers',
    lat: 36.7450,
    lng: 3.1090,
    status: 'available',
    timestamp: Date.now() - 170000,
    imageUrl: 'https://images.unsplash.com/photo-1606144042858-a55181b5c4df?auto=format&fit=crop&q=80&w=800'
  },
  {
    userId: '+213553776497',
    title: 'Board Games Bundle',
    description: 'Monopoly and Scrabble. Missing some pieces maybe.',
    category: 'Toys',
    location: 'Hydra, Algiers',
    lat: 36.7388,
    lng: 3.0336,
    status: 'available',
    timestamp: Date.now() - 180000,
    imageUrl: 'https://images.unsplash.com/photo-1610890716171-6b1e220f865f?auto=format&fit=crop&q=80&w=800'
  },
  {
    userId: '+213553776497',
    title: 'Living Room Rug',
    description: '2x3 meters. Needs a wash.',
    category: 'Furniture',
    location: 'El Biar, Algiers',
    lat: 36.7629,
    lng: 3.0306,
    status: 'available',
    timestamp: Date.now() - 190000,
    imageUrl: 'https://images.unsplash.com/photo-1554188248-986ad55225c9?auto=format&fit=crop&q=80&w=800'
  },
  {
    userId: '+213553776497',
    title: 'Bag of Sweaters',
    description: 'Various sizes, mostly L and XL.',
    category: 'Clothes',
    location: 'Zeralda, Algiers',
    lat: 36.7118,
    lng: 2.8427,
    status: 'available',
    timestamp: Date.now() - 200000,
    imageUrl: 'https://images.unsplash.com/photo-1556821840-3a63f95609a7?auto=format&fit=crop&q=80&w=800'
  },
  {
    userId: '+213553776497',
    title: 'Desk Lamp',
    description: 'LED desk lamp, adjustable arm.',
    category: 'Electronics',
    location: 'Bab Ezzouar, Algiers',
    lat: 36.7214,
    lng: 3.1858,
    status: 'available',
    timestamp: Date.now() - 210000,
    imageUrl: 'https://images.unsplash.com/photo-1507473885765-e6ed057f782c?auto=format&fit=crop&q=80&w=800'
  },
  {
    userId: '+213553776497',
    title: 'Guitar Strings (New)',
    description: 'Bought the wrong ones. Unopened.',
    category: 'Books & Media',
    location: 'Cheraga, Algiers',
    lat: 36.7645,
    lng: 2.9566,
    status: 'available',
    timestamp: Date.now() - 220000,
    imageUrl: 'https://images.unsplash.com/photo-1510915361894-db8b60106cb1?auto=format&fit=crop&q=80&w=800'
  },
  {
    userId: '+213553776497',
    title: 'Camping Tent (2 Person)',
    description: 'Used a few times, good condition.',
    category: 'Other',
    location: 'Kouba, Algiers',
    lat: 36.7297,
    lng: 3.0881,
    status: 'available',
    timestamp: Date.now() - 230000,
    imageUrl: 'https://images.unsplash.com/photo-1537225228614-56cc3556d7ed?auto=format&fit=crop&q=80&w=800'
  },
  {
    userId: '+213553776497',
    title: 'Fresh Oranges',
    description: 'From our garden tree, about 5kg.',
    category: 'Food',
    location: 'El Harrach, Algiers',
    lat: 36.7167,
    lng: 3.1333,
    status: 'available',
    timestamp: Date.now() - 240000,
    imageUrl: 'https://images.unsplash.com/photo-1611080626919-7cf5a9dbab5b?auto=format&fit=crop&q=80&w=800'
  },
  {
    userId: '+213553776497',
    title: 'LEGO Blocks Box',
    description: 'Random lego pieces, 2kg box.',
    category: 'Toys',
    location: 'Bab Ezzouar, Algiers',
    lat: 36.7214,
    lng: 3.1858,
    status: 'available',
    timestamp: Date.now() - 250000,
    imageUrl: 'https://images.unsplash.com/photo-1585366119957-e9730b6d0f60?auto=format&fit=crop&q=80&w=800'
  },
  {
    userId: '+213553776497',
    title: 'Old Bookshelf',
    description: 'Wood bookshelf, 4 shelves.',
    category: 'Furniture',
    location: 'Hydra, Algiers',
    lat: 36.7388,
    lng: 3.0336,
    status: 'available',
    timestamp: Date.now() - 260000,
    imageUrl: 'https://images.unsplash.com/photo-1507646870535-61da68eb51f8?auto=format&fit=crop&q=80&w=800'
  },
  {
    userId: '+213553776497',
    title: 'Winter Boots',
    description: 'Size 42, waterproof.',
    category: 'Clothes',
    location: 'Bir Mourad Rais, Algiers',
    lat: 36.7328,
    lng: 3.0478,
    status: 'available',
    timestamp: Date.now() - 270000,
    imageUrl: 'https://images.unsplash.com/photo-1605348532760-6753d2c43329?auto=format&fit=crop&q=80&w=800'
  },
  {
    userId: '+213553776497',
    title: 'Rice Cooker',
    description: 'Small rice cooker, fully functional.',
    category: 'Electronics',
    location: 'Caroubier, Algiers',
    lat: 36.7450,
    lng: 3.1090,
    status: 'available',
    timestamp: Date.now() - 280000,
    imageUrl: 'https://images.unsplash.com/photo-1584269600519-112d071b4d16?auto=format&fit=crop&q=80&w=800'
  },
  {
    userId: '+213553776497',
    title: 'Paintings (Set of 3)',
    description: 'Abstract art, 50x50cm each.',
    category: 'Other',
    location: 'Sidi Yahia, Algiers',
    lat: 36.7450,
    lng: 3.0300,
    status: 'available',
    timestamp: Date.now() - 290000,
    imageUrl: 'https://images.unsplash.com/photo-1579783902614-a3fb3927b6a5?auto=format&fit=crop&q=80&w=800'
  }
];

let count = 0;
items.forEach((item) => {
  const req = https.request(dbUrl, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' }
  }, (res) => {
    count++;
    if(count === items.length) {
      console.log('Successfully pushed 30 items.');
    }
  });

  req.write(JSON.stringify(item));
  req.end();
});
