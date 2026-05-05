1. GET /api/v1/admin/salon                                                                                                 
                                                                                                                             
  ▎ Get salon information                                                                                                    
                                                                                                                             
  {                                                                                                                          
    "id": "c7b73692-c147-4778-83c1-8ee9caaabfdd",           
    "name": "Test Salon",                                                                                                    
    "location": "Test Location",                            
    "phone": "+237 600 000 000",
    "businessHours": {                                                                                                       
      "weekdays": { "open": "09:00", "close": "18:00" },
      "weekends": { "open": "10:00", "close": "16:00" },                                                                     
      "daysOff": ["Sunday"]                                                                                                  
    },                                    
    "subscriptionPlan": "Free Trial",                                                                                        
    "subscriptionPrice": 0,                                                                                                  
    "billingCycle": "monthly",            
    "subscriptionStatus": "trial",                                                                                           
    "maxStylists": 3,                                                                                                        
    "features": ["Online Booking", "Basic Analytics"]
  }                                                                                                                          
                                                                                                                             
  ---
  2. PUT /api/v1/admin/salon                                                                                                 
                                                            
  ▎ Update salon information                                                                                                 
                                                            
  Request body (all fields optional):         
  {                                       
    "name": "LIS Beauty Douala",
    "location": "Rue de Bonaberi, Douala",                                                                                   
    "phone": "+237 699 123 456",              
    "businessHours": {                                                                                                       
      "weekdays": { "open": "08:00", "close": "19:00" },    
      "weekends": { "open": "09:00", "close": "15:00" },                                                                     
      "daysOff": ["Sunday"]
    }                                                                                                                        
  }                                                         
                                                                                                                             
  ---                                                                                                                        
  3. GET /api/v1/admin/salon/subscription
                                                                                                                             
  ▎ Get subscription details                                

  {                                                                                                                          
    "plan": "Free Trial",
    "price": 0,                                                                                                              
    "billingCycle": "monthly",                              
    "status": "trial",
    "maxStylists": 3,                         
    "features": ["Online Booking", "Basic Analytics"]
  }
                                                                                                                             
  ---
  4. GET /api/v1/admin/settings/loyalty-config                                                                               
                                                            
  ▎ Get loyalty program config            

  {                                                                                                                          
    "id": "uuid",
    "salonId": "c7b73692-c147-4778-83c1-8ee9caaabfdd",                                                                       
    "pointsPer500Fcfa": 10,                                 
    "punchCardVisits": 5,                     
    "punchCardReward": "Free service up to 5,000 FCFA",                                                                      
    "birthdayReward": 50,                     
    "referralBonus": 100                                                                                                     
  }                                                                                                                          
                                                                                                                             
  ---                                                                                                                        
  5. PUT /api/v1/admin/settings/loyalty-config                                                                               
                                                            
  ▎ Update loyalty config                                                                                                    
                                                            
  Request body (all fields optional):
  {
    "pointsPer500Fcfa": 15,
    "punchCardVisits": 8,  
    "birthdayReward": 100,
    "referralBonus": 200                      
  }                                       

  ---                                                                                                                        
  6. GET /api/v1/admin/salon/stylists
                                                                                                                             
  ▎ List all stylists                                       

  [                                                                                                                          
    {
      "id": "uuid",                                                                                                          
      "name": "Jean-Paul",                                  
      "specialty": "Braids & Locs",           
      "photoUrl": "/uploads/stylist.jpg", 
      "salonId": "c7b73692-...",
      "rating": 4.5,                                                                                                         
      "active": true                      
    }                                                                                                                        
  ]                                                                                                                          
  
  ---                                                                                                                        
  7. POST /api/v1/admin/salon/stylists                      
                                              
  ▎ Create a stylist                      

  {                                                                                                                          
    "name": "Jean-Paul",
    "specialty": "Braids & Locs",                                                                                            
    "photoUrl": "/uploads/stylist.jpg"                      
  }                                           
                                          
  ---
  8. PUT /api/v1/admin/salon/stylists/:id                                                                                    
  
  ▎ Update a stylist                                                                                                         
                                                            
  9. DELETE /api/v1/admin/salon/stylists/:id  
                                          
  ▎ Delete a stylist
                                                                                                                             
  ---
  10. GET /api/v1/admin/services                                                                                             
                                                            
  ▎ List all salon services

  [
    {
      "id": "uuid",                           
      "name": "Deep Conditioning",        
      "nameKey": "services.deep_conditioning",
      "category": "treatment",                                                                                               
      "duration": 45,                         
      "price": 3000,                                                                                                         
      "salonId": "c7b73692-..."                             
    }                                                                                                                        
  ]
                                                                                                                             
  11. POST /api/v1/admin/services                           
                                          
  ▎ Create a service
                                                                                                                             
  {
    "name": "Deep Conditioning",                                                                                             
    "nameKey": "services.deep_conditioning",                
    "category": "treatment",
    "duration": 45,
    "price": 3000                             
  }                                       

  12. PUT /api/v1/admin/services/:id / DELETE /api/v1/admin/services/:id                                                     
                                          
  ---                                                                                                                        
  All endpoints require Authorization: Bearer <token> with an admin token. Want me to add any missing settings (e.g.,        
  notification preferences, salon logo upload)?
                                                                 