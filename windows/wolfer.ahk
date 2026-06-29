

; ============================================================================
; wolfer.ahk — KDE-style "grab anywhere" window move/resize for Windows
; ============================================================================
;
; WHAT THIS DOES
;   Lets you move and resize ANY window by holding Alt and dragging with the
;   mouse anywhere inside it (like KDE/GNOME on Linux), instead of having to aim
;   at the tiny title bar or window edges:
;     - Alt + Left-drag    = move the window
;     - Alt + Right-drag   = resize the window (the corner nearest the cursor)
;     - Right+Left click    = minimize the window
;     - Left+Right click    = maximize / restore the window
;     - Middle + any other  = close the window
;   ("wolfer" is a long-circulated community AutoHotkey script; the chatty
;    comments below are the original author's.)
;
; HOW TO RUN
;   Install AutoHotkey v1 (https://www.autohotkey.com), then double-click this
;   .ahk file (or put a shortcut to it in your Startup folder so it runs at
;   login). A green "H" tray icon appears; right-click it to exit/reload.
;
; PREREQUISITES: AutoHotkey v1.x (this uses v1 syntax; it will NOT run under v2).
;
; AUTOHOTKEY SYNTAX CHEAT-SHEET (used throughout this file)
;   ;            starts a comment (AHK uses ; not #)
;   !            modifier meaning the Alt key, e.g. !LButton = Alt + Left mouse
;   LButton / RButton / MButton = the left / right / middle mouse buttons
;   ~            "pass-through" prefix: still send the normal click to Windows
;                while also firing our hotkey (so clicks aren't swallowed)
;   &            chord operator: "A & B" = press A, then B, to trigger
;   Label::      defines a hotkey or label; the lines under it run until "return"
;   :=           assignment of an expression;  %var% expands a variable's value
; ============================================================================

;==============================================================
; Alternate picks between two behavior "sets". false = the default set below.
Alternate := false ; Set to true for the alternate set. I bet 
                   ; that was tough to figure out, huh?
; SetWinDelay sets how long AHK pauses after each window move/resize command.
; 0 = no pause = the smoothest, most responsive dragging.
SetWinDelay,0 ; The lower, the faster. Keep in mind that faster 
              ; doesn't necessarily mean better.
;==============================================================


; If you like having fun breaking scripts, remove
; the line below. I haven't tried it yet. ;-D
; CoordMode,Mouse makes all mouse X/Y positions relative to the whole screen,
; so the window-position math below lines up correctly.
CoordMode,Mouse 
; This auto-execute section runs once at startup. Based on the Alternate flag,
; it turns specific hotkeys on or off via the Hotkey command. "off" disables a
; hotkey so the listed button combos behave normally.
If Alternate 
{ 
   ; Alternate set: bind Alt+Left/Right to the Alternate1/Alternate2 labels and
   ; switch off the middle-button and double-Alt behaviors.
   Hotkey,!LButton,Alternate1 
   Hotkey,!RButton,Alternate2 
   Hotkey,!MButton,off 
   Hotkey,~Alt,off 
} 
Else 
{ 
   ; Default set: disable the two-button chord hotkeys defined later in the
   ; file so the plain Alt+drag hotkeys are the ones in effect.
   Hotkey,~RButton & LButton,off 
   Hotkey,~LButton & RButton,off 
   Hotkey,~MButton & RButton,off 
   Hotkey,~MButton & LButton,off 
   Hotkey,~RButton & MButton,off 
   Hotkey,~LButton & MButton,off 
} 
; "return" ends the auto-execute section; everything after this point only runs
; when its hotkey is pressed.
return 

; HOTKEY: Alt + Left mouse button held = MOVE the window under the cursor.
!LButton:: 

; Record the starting mouse position (KDE_X1,KDE_Y1) and the window under the
; cursor (KDE_id). We compare against these as the mouse moves.
MouseGetPos,KDE_X1,KDE_Y1,KDE_id 
; The code below checks if the window's
; maximized. Obviously, it terminates 
; if it is. 
WinGet,KDE_Win,MinMax,ahk_id %KDE_id% 
If KDE_Win 
   return 
WinGetPos,KDE_WinX1,KDE_WinY1,,,ahk_id %KDE_id% 
Loop ; I took the timer off. For some reason I like loops better. 
{ 
   GetKeyState,KDE_Button,LButton,P                  ; 1 
   If KDE_Button = U                                 ; 2 
      break                                        ; 3 
   MouseGetPos,KDE_X2,KDE_Y2                         ; 4 
   KDE_X2 -= KDE_X1                                  ; 5 
   KDE_Y2 -= KDE_Y1                                  ; 6 
   KDE_WinX2 := (KDE_WinX1 + KDE_X2)                 ; 7 
   KDE_WinY2 := (KDE_WinY1 + KDE_Y2)                 ; 8 
   WinMove,ahk_id %KDE_id%,,%KDE_WinX2%,%KDE_WinY2%  ; 9 
   ; WHOA, right? I'll try to explain: 
   ; 1-3: Check the LButton state. If up, break. 
   ; 4: Grab the current mouse position. 
   ; 5-6: Subtract the current mouse position from the original one. 
   ;   This generates an offset from the current position. 
   ; 7-8: Add the offset to the original position of the window. 
   ; 9: The only part that actually does something. Guess what it is. 
} 
return 

; This is the above code without the unused double-alt.
; LABEL Alternate1: the "move window" routine used when Alternate := true.
; Same logic as the !LButton:: block above.
Alternate1: 
MouseGetPos,KDE_X1,KDE_Y1,KDE_id 
WinGet,KDE_Win,MinMax,ahk_id %KDE_id% 
If KDE_Win 
   return 
WinGetPos,KDE_WinX1,KDE_WinY1,,,ahk_id %KDE_id% 
Loop 
{ 
   GetKeyState,KDE_Button,LButton,P 
   If KDE_Button = U 
      break 
   MouseGetPos,KDE_X2,KDE_Y2 
   KDE_X2 -= KDE_X1 
   KDE_Y2 -= KDE_Y1 
   KDE_WinX2 := (KDE_WinX1 + KDE_X2) 
   KDE_WinY2 := (KDE_WinY1 + KDE_Y2) 
   WinMove,ahk_id %KDE_id%,,%KDE_WinX2%,%KDE_WinY2% 
} 
return 

; HOTKEY: Alt + Right mouse button held = RESIZE the window under the cursor.
; It figures out which corner the mouse is nearest and drags that corner.
!RButton:: 

; Record the starting mouse position and the target window id.
MouseGetPos,KDE_X1,KDE_Y1,KDE_id 
; Again, just checking if it's already
; maximized. I'm surprised none of this 
; script's predecessors had this. 
WinGet,KDE_Win,MinMax,ahk_id %KDE_id% 
If KDE_Win 
   return 
WinGetPos,KDE_WinX1,KDE_WinY1,KDE_WinW,KDE_WinH,ahk_id %KDE_id% 
; Ok, now we're checking to see what corner the mouse is 
; in. This basically sets up 4 "regions" in the window and 
; lets the Loop formula below know which one to act in. 
; Translation of formula: If Mouse X is less than Window X 
; and half of Window Width. 
If (KDE_X1 < KDE_WinX1 + KDE_WinW / 2) 
   KDE_WinLeft := true 
Else 
   KDE_WinLeft := false 
If (KDE_Y1 < KDE_WinY1 + KDE_WinH / 2) 
   KDE_WinUp := true 
Else 
   KDE_WinUp := false 

Loop 
{ 
   GetKeyState,KDE_Button,RButton,P    ; 1 
   If KDE_Button = U                   ; 2 
      break                            ; 3 
   MouseGetPos,KDE_X2,KDE_Y2           ; 4 
   WinGetPos,KDE_WinX1,KDE_WinY1,KDE_WinW,KDE_WinH,ahk_id %KDE_id%  ; 5 
   KDE_X2 -= %KDE_X1%                  ; 6 
   KDE_Y2 -= %KDE_Y1%                  ; 7 
   If KDE_WinLeft                      ; 8 
   {                                   ; 9 
      KDE_WinX1 += %KDE_X2%            ; 10 
      KDE_WinW -= %KDE_X2%             ; 11 
   }                                   ; 12 
   Else                                ; 13 
      KDE_WinW += %KDE_X2%             ; 14 
   If KDE_WinUp                        ; 15 
   {                                   ; 16 
      KDE_WinY1 += %KDE_Y2%            ; 17 
      KDE_WinH -= %KDE_Y2%             ; 18 
   }                                   ; 19 
   Else                                ; 20 
      KDE_WinH += %KDE_Y2%             ; 21 
   WinMove,ahk_id %KDE_id%,,%KDE_WinX1%,%KDE_WinY1%,%KDE_WinW%,%KDE_WinH% ; 22 
   KDE_X1 := (KDE_X2 + KDE_X1)         ; 23 
   KDE_Y1 := (KDE_Y2 + KDE_Y1)         ; 24 
   ; Ya, um... ok. Wow. This was hard to 
   ; wade through and figure out at first, 
   ; but eventually I got this working. 
   ; I'll TRY to explain: 
   ; 1-3: Check the RButton state. If up, break. 
   ; 4-5: Grabs the necessary info. If you don't think it's necessary 
   ;   to grab the WinPos again, well, you might be right. Just be 
   ;   prepared to make some big changes to the formula below it. 
   ; 6-7: Subtract to get an offset from the current position. 
   ; 8-12: If the mouse was found to be on the left side, 
   ;   subtract the offset from the width (to reverse it.) 
   ;   Then, add the offset to the X axis to correct the 
   ;   window's position. If you don't think that's necessary, 
   ;   screw with this a little and see for yourself. 
   ; 13-14: If not, add the offset to the width. No correction 
   ;   is necessary. 
   ; 15-19: Same as above, but for the Y axis and height. 
   ; 20-21: Ditto. 
   ; 22: Move the window to it's new size, and yes: position. 
   ;   As shown above, it requires a correction if the offset 
   ;   was reversed. Hope it makes sense. :-/ 
   ; 23-24: Set the current mouse position to "old" for the 
   ;   next iteration. I changed it to this expression-based 
   ;   version to avoid adding yet another variable. 
} 
return 

; LABEL Alternate2: the "resize window" routine used when Alternate := true.
; Same logic as the !RButton:: block above.
Alternate2: 
MouseGetPos,KDE_X1,KDE_Y1,KDE_id 
WinGet,KDE_Win,MinMax,ahk_id %KDE_id% 
If KDE_Win 
   return 
WinGetPos,KDE_WinX1,KDE_WinY1,KDE_WinW,KDE_WinH,ahk_id %KDE_id% 
If (KDE_X1 < KDE_WinX1 + KDE_WinW / 2) 
   KDE_WinLeft := true 
Else 
   KDE_WinLeft := false 
If (KDE_Y1 < KDE_WinY1 + KDE_WinH / 2) 
   KDE_WinUp := true 
Else 
   KDE_WinUp := false 
Loop 
{ 
   GetKeyState,KDE_Button,RButton,P 
   If KDE_Button = U 
      break 
   MouseGetPos,KDE_X2,KDE_Y2 
   WinGetPos,KDE_WinX1,KDE_WinY1,KDE_WinW,KDE_WinH,ahk_id %KDE_id% 
   KDE_X2 -= %KDE_X1% 
   KDE_Y2 -= %KDE_Y1% 
   If KDE_WinLeft 
   { 
      KDE_WinX1 += %KDE_X2% 
      KDE_WinW -= %KDE_X2% 
   } 
   Else 
      KDE_WinW += %KDE_X2% 
   If KDE_WinUp 
   { 
      KDE_WinY1 += %KDE_Y2% 
      KDE_WinH -= %KDE_Y2% 
   } 
   Else 
      KDE_WinH += %KDE_Y2% 
   WinMove,ahk_id %KDE_id%,,%KDE_WinX1%,%KDE_WinY1%,%KDE_WinW%,%KDE_WinH% 
   KDE_X1 := (KDE_X2 + KDE_X1) 
   KDE_Y1 := (KDE_Y2 + KDE_Y1) 
} 
return 

; HOTKEY: Alt + Middle mouse button. Only does anything if a DoubleAlt flag was
; set (that feature isn't wired up here), so in practice this is a no-op.
!MButton:: 
If DoubleAlt 
{ 
   ; Close the window under the cursor, then clear the flag.
   MouseGetPos,,,KDE_id 
   WinClose,ahk_id %KDE_id% 
   DoubleAlt := false 
   return 
} 
return 

; Urk. Yes, I know the pass-through is 
; superbly annoying, but I swear I tried 
; for at least half an hour, tweaking with 
; these darn combos and this is the best 
; working stuff I got. Either think up 
; different combos or make this work right 
; if you're too annoyed to live with it. 
; CHORD: hold Right button, then click Left = MINIMIZE the window under cursor.
; The ~ keeps the normal right-click working too.
~RButton & LButton:: 
MouseGetPos,,,KDE_id 
; PostMessage sends a raw Windows message: 0x112 = WM_SYSCOMMAND,
; 0xf020 = SC_MINIMIZE — i.e. "minimize this window".
PostMessage,0x112,0xf020,,,ahk_id %KDE_id% 
return 

; CHORD: hold Left button, then click Right = toggle MAXIMIZE/RESTORE the window.
~LButton & RButton:: 
MouseGetPos,,,KDE_id 
; WinGet ...,MinMax reports if the window is maximized (1), normal (0), or
; minimized (-1). If it's already maximized, restore it; otherwise maximize it.
WinGet,KDE_Win,MinMax,ahk_id %KDE_id% 
If KDE_Win 
   WinRestore,ahk_id %KDE_id% 
Else 
   WinMaximize,ahk_id %KDE_id% 
return 

; CHORD: any middle-button + another-button combo = CLOSE the window under the
; cursor. Stacking four labels means all four combos run the same code below.
~MButton & RButton:: 
~MButton & LButton:: 
~RButton & MButton:: 
~LButton & MButton:: 
MouseGetPos,,,KDE_id 
WinClose,ahk_id %KDE_id% 
return