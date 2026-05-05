: com.example.hairstyle:f87a4a72: onCancelled at PHASE_CLIENT_ALREADY_HIDDEN
I/flutter (13086): [TryOn] Loaded reference image: assets/hairstyles/curly pixie wig.png (94.2 KB)
I/flutter (13086): [Gemini Debug] ====== STARTING HAIRSTYLE GENERATION ======
I/flutter (13086): [Gemini Debug] Style: Curly Pixie Wig
I/flutter (13086): [Gemini Debug] Photo size: 64699 bytes (63.2 KB)
I/flutter (13086): [Gemini Debug] Style image: 94.2 KB
I/flutter (13086): [Gemini Debug] Hair color: natural
I/flutter (13086): [Gemini Debug] Trying model: gemini-2.5-pro-preview-06-05
I/flutter (13086): [Gemini Debug] URL: https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-pro-preview-06-05:generateContent?key=API_KEY_HIDDEN
I/flutter (13086): [Gemini Debug] Sending request (attempt 1)...
I/flutter (13086): [Gemini Debug] Response status: 404 (took 1630ms)
I/flutter (13086): [Gemini Debug] 404 — Model "gemini-2.5-pro-preview-06-05" not found. Response: {
I/flutter (13086):   "error": {
I/flutter (13086):     "code": 404,
I/flutter (13086):     "message": "models/gemini-2.5-pro-preview-06-05 is not found for API version v1beta, or is not supported for generateContent. Call ListModels to see the list of available models and their supported methods.",
I/flutter (13086):     "status": "NOT_FOUND"
I/flutter (13086):   }
I/flutter (13086): }
I/flutter (13086): 
I/flutter (13086): [Gemini Debug] Trying model: gemini-2.5-pro-exp-03-25
I/flutter (13086): [Gemini Debug] URL: https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-pro-exp-03-25:generateContent?key=API_KEY_HIDDEN
I/flutter (13086): [Gemini Debug] Sending request (attempt 1)...
I/flutter (13086): [Gemini Debug] Response status: 404 (took 1262ms)
I/flutter (13086): [Gemini Debug] 404 — Model "gemini-2.5-pro-exp-03-25" not found. Response: {
I/flutter (13086):   "error": {
I/flutter (13086):     "code": 404,
I/flutter (13086):     "message": "models/gemini-2.5-pro-exp-03-25 is not found for API version v1beta, or is not supported for generateContent. Call ListModels to see the list of available models and their supported methods.",
I/flutter (13086):     "status": "NOT_FOUND"
I/flutter (13086):   }
I/flutter (13086): }
I/flutter (13086): 
I/flutter (13086): [Gemini Debug] Trying model: gemini-2.5-flash-preview-04-17
I/flutter (13086): [Gemini Debug] URL: https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-preview-04-17:generateContent?key=API_KEY_HIDDEN
I/flutter (13086): [Gemini Debug] Sending request (attempt 1)...
I/flutter (13086): [Gemini Debug] Response status: 404 (took 1328ms)
I/flutter (13086): [Gemini Debug] 404 — Model "gemini-2.5-flash-preview-04-17" not found. Response: {
I/flutter (13086):   "error": {
I/flutter (13086):     "code": 404,
I/flutter (13086):     "message": "models/gemini-2.5-flash-preview-04-17 is not found for API version v1beta, or is not supported for generateContent. Call ListModels to see the list of available models and their supported methods.",
I/flutter (13086):     "status": "NOT_FOUND"
I/flutter (13086):   }
I/flutter (13086): }
I/flutter (13086): 
I/flutter (13086): [Gemini Debug] Trying model: gemini-2.5-flash-image
I/flutter (13086): [Gemini Debug] URL: https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-image:generateContent?key=API_KEY_HIDDEN
I/flutter (13086): [Gemini Debug] Sending request (attempt 1)...
I/flutter (13086): [Gemini Debug] Response status: 200 (took 11461ms)
I/flutter (13086): [Gemini Debug] SUCCESS with model: gemini-2.5-flash-image
I/flutter (13086): [Gemini Debug] Finish reason: STOP
I/flutter (13086): [Gemini Debug] Response has 1 part(s)
I/flutter (13086): [Gemini Debug] Got image: image/png, 1670949 bytes
I/flutter (13086): [Gemini Debug] Generated image size: 1670949 bytes

══╡ EXCEPTION CAUGHT BY RENDERING LIBRARY
╞═════════════════════════════════════════════════════════
The following assertion was thrown during layout:
A RenderFlex overflowed by 36 pixels on the right.