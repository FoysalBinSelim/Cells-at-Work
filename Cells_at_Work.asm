.MODEL small
.STACK 100h

.data

filename db 'test.bmp',0

filehandle dw ?

Header db 54 dup (0)

Palette db 256*4 dup (0)

ScrLine db 320 dup (0)

ErrorMsg db 'Error', 13, 10,'$'  

;/////////////////////////////////////////////

player_x dw 0 
player_y dw 240
player_ep dw ?

score_count dw 48 
life_count dw 53

bact1_x dw 620
bact1_y dw 300
bact1_ep dw ?

bact2_x dw 300
bact2_y dw 20
bact2_ep dw ?

bact3_x dw 20
bact3_y dw 100
bact3_ep dw ? 

gem_x dw 500
gem_y dw 300
gem_ep dw 0

;\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\

msg db 'score : $'
msg1 db 09H,09H,09H,09H,09H,09H,09H,' Life : $'

lmsg0 db 0dh,0ah,0dh,0ah,0dh,0ah,0dh,0ah,24h
lmsg1 db 0dh,0ah,"                  ===================================================                  $"
lmsg2 db 0dh,0ah,"                                        GAME OVER!!!                     $"
lmsg3 db 0dh,0ah,"                  ===================================================                  $"

lmsg4 db 0dh,0ah,"                                        YOUR SCORE :$"
 
randnumber dw 0

;////////////////////////////////////////////   code segment
.code

;////////////////////////////////////////////print number  and newline begin
printNum macro num
    push ax
    push bx
    push cx
    push dx
    
    mov ax,num
    sub ax,48  
    
    local conditionx,exit2,done
    

    mov bx,10
    mov cx,0
    
    conditionx:   
        mov dx,0 
        
        cmp ax,0
        je exit2
        
        div bx
        
        inc cx
        push dx
        
        jmp conditionx
               
        exit2: 
            cmp cx,0
            je done 
            
            dec cx
            
            pop dx
            add dx,48
            mov ah,2
            int 21h
            
            jmp exit2
            
            done:
       pop dx
       pop cx
       pop bx
       pop ax
       
endm


;\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\print number and newline end

pushall macro
    push ax
    push bx
    push cx
    push dx
  endm

popall macro
    pop dx
    pop cx
    pop bx
    pop ax
endm
;////////////////////////////////////////////print macro
print macro msgg
    lea dx,msgg
    mov ah,9
    int 21h
endm
;\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\end print macro
;///////////////////////////////////////////delay macro begindelay macro
delay macro
    
       ; mov cx,1000
;       L81:
;       loop L81 

 
 
    push dx 

    MOV     CX, 0FH
    MOV     DX, 4240H
    MOV     AH, 86H
    INT     15H
       
     pop dx
    
endm
 
;\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\delay macro end
; following macro stores a random value using system time
; into cur variable (word)
getrand_x macro cur 
    pushall
    mov cx,0
    
    mov ah, 0
    int 1ah
    
    mov ax, dx
    mov dx, cx  ;dx:ax contains system time
    
    mov bx, 7261
    mul ax
    add ax, 1
    mov dx, 0
    mov bx, 640
    div bx
    
    mov cur, dx
    popall
endm 

getrand_y macro cur 
    pushall
    mov cx,0
    
    mov ah, 0
    int 1ah
    
    mov ax, dx
    mov dx, cx  ;dx:ax contains system time
    
    mov bx, 7261
    mul ax
    add ax, 1
    mov dx, 0
    mov bx, 480
    div bx
    
    mov cur, dx
    popall
 endm

rounding macro rand
    pushall
    
    mov dx,0
    mov cx,10
    mov ax,rand
    
    div cx
    
    mov ax,rand
    sub ax,dx
    
    mov rand,ax
    
    popall 
endm
;
;\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\random numberend


 OpenFile proc

                                    ; Open file

    mov ah, 3Dh
    xor al, al
    mov dx, offset filename
    int 21h

    jc openerror
    mov [filehandle], ax
    ret

    openerror:
    mov dx, offset ErrorMsg
    mov ah, 9h
    int 21h
    ret
endp OpenFile


ReadHeader  proc

                                   ; Read BMP file header, 54 bytes

    mov ah,3fh
    mov bx, [filehandle]
    mov cx,54
    mov dx,offset Header
    int 21h
    ret
    endp ReadHeader


ReadPalette   proc

                                   ; Read BMP file color palette, 256 colors * 4 bytes (400h)

    mov ah,3fh
    mov cx,400h
    mov dx,offset Palette
    int 21h
    ret
endp ReadPalette



CopyPal proc
                                
                                    ; Copy the colors palette to the video memory
                                    ; The number of the first color should be sent to port 3C8h
                                    ; The palette is sent to port 3C9h

    mov si,offset Palette
    mov cx,256
    mov dx,3C8h
    mov al,0

                                    ; Copy starting color to port 3C8h

    out dx,al

                                    ; Copy palette itself to port 3C9h

    inc dx
    PalLoop:   
                                    ; Note: Colors in a BMP file are saved as BGR values rather than RGB.
    
        mov al,[si+2]               ; Get red value.
        shr al,2                    ; Max. is 255, but video palette maximal
    
                                    ; value is 63. Therefore dividing by 4.
    
        out dx,al                   ; Send it.
        mov al,[si+1]               ; Get green value.
        shr al,2
        out dx,al                   ; Send it.
        mov al,[si]                 ; Get blue value.
        shr al,2
        out dx,al                   ; Send it.
        add si,4                    ; Point to next color.
    
                                    ; (There is a null chr. after every color.)
    
        loop PalLoop
    ret
endp CopyPal

 CopyBitmap   proc

                                    ; BMP graphics are saved upside-down.
                                    ; Read the graphic line by line (200 lines in VGA format),
                                    ; displaying the lines from bottom to top.

    mov ax, 0A000h
    mov es, ax
    mov cx,200
    PrintBMPLoop:
        push cx
    
                                    ; di = cx*320, point to the correct screen line
    
        mov di,cx
        shl cx,6
        shl di,8
        add di,cx
    
                                    ; Read one line
    
        mov ah,3fh
        mov cx,320
        mov dx,offset ScrLine
        int 21h
    
                                    ; Copy one line into video memory
    
        cld     
                                    ; Clear direction flag, for movsb
    
        mov cx,320
        mov si,offset ScrLine
        rep movsb 
        pop cx
        loop PrintBMPLoop
    ret
 endp CopyBitmap           
 
 
;================================

;/////////////////////////////////score_processing
score_processing proc
    push dx
        
    mov dx,player_x
    cmp dx,gem_x
    
    je x_equal
    jmp skip 
    
    x_equal:
        mov dx,player_y
        cmp dx,gem_y
        jne skip
        
        call initialize_gem
        inc score_count
        
    skip:
    
    pop dx
    ret
score_processing endp
;\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\end score_processing 
;/////////////////////////////////life_processing1
life_processing1 proc
    push dx
        
    mov dx,player_x
    cmp dx,bact1_x
    
    je x_equal1
    jmp skip1 
    
    x_equal1:
        mov dx,player_y
        cmp dx,bact1_y
        jne skip1
        
        dec life_count
        
    skip1:
    
    
    pop dx
    ret
life_processing1 endp
;\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\end life_processing1
;/////////////////////////////////life_processing2
life_processing2 proc
    push dx
        
    mov dx,player_x
    cmp dx,bact2_x
    
    je x_equal2
    jmp skip2 
    
    x_equal2:
        mov dx,player_y
        cmp dx,bact2_y
        jne skip2
        
        dec life_count
        
    skip2:
    
    pop dx
    ret
life_processing2 endp
;\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\end life_processing2 
;///////////////////////////////////////////////initializing begin
initialize_gem proc    
    pushall
    
    getrand_x randnumber
    rounding randnumber
    
    mov dx,randnumber
    mov gem_x,dx
    
    getrand_y randnumber
    rounding randnumber
    
    mov dx,randnumber 
    mov gem_y,dx
    
               
    popall
    ret        
initialize_gem endp
;\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\end initializing

;//////////////////////////////////////////////begin bact1_draw
 
 
 ;////////////////////////////////////////////////drawing bact1 
draw_bact1 proc
   pushall 
    
;bact1_draw:

   
    ;mov ah,0
;    mov al,12h
;    int 10h
;    
;    
;    mov ah,0ch    
    mov al,14
    mov cx,bact1_x
    mov dx,bact1_y
    
    mov bact1_ep,cx
    add bact1_ep,20
    
    
    bact1_lp1:
    
    int 10h
    inc cx
    cmp cx,bact1_ep
    jne bact1_lp1  
    
    ;mov al,2
    ;mov cx,x
    mov dx,bact1_y
    
    mov bact1_ep,dx
    add bact1_ep,16
    
    
    bact1_lp2:
    
        int 10h
        inc dx
        cmp dx,bact1_ep
        jne bact1_lp2
        
         
        
        ;mov al,2
        mov cx,bact1_x
        mov dx,bact1_y
        
        mov bact1_ep,dx
        add bact1_ep,16
    
    
    bact1_lp3:
        int 10h
        inc dx
        cmp dx,bact1_ep
        jne bact1_lp3
        
        
        ;mov al,2
        mov cx,bact1_x
    
    
    mov bact1_ep,cx
    add bact1_ep,20
    
    
    bact1_lp4:
        int 10h
        inc cx
        cmp cx,bact1_ep
        jne bact1_lp4
        
        sub bact1_x,1
        mov dx,bact1_x
        cmp dx,0
        
        jne continue1
        
        mov bact1_x,640
        continue1:
        
        
    popall
    ret    
draw_bact1 endp        

;\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\end bact1_draw

;///////////////////////////////////////////////begin bact2_draw

draw_bact2 proc
    pushall    

;bact2_draw:

   
;    mov ah,0
;    mov al,12h
;    int 10h
;    
    
;    mov ah,0ch    
    mov al,4
    mov cx,bact2_x
    mov dx,bact2_y
    
    mov bact2_ep,cx
    add bact2_ep,20
    
    
    bact2_lp1:
    
    int 10h
    inc cx
    cmp cx,bact2_ep
    jne bact2_lp1  
    
    ;mov al,2
    ;mov cx,x
    mov dx,bact2_y
    
    mov bact2_ep,dx
    add bact2_ep,16
    
    
    bact2_lp2:
    
        int 10h
        inc dx
        cmp dx,bact2_ep
        jne bact2_lp2
        
         
        
        ;mov al,2
        mov cx,bact2_x
        mov dx,bact2_y
        
        mov bact2_ep,dx
        add bact2_ep,16
    
    
    bact2_lp3:
        int 10h
        inc dx
        cmp dx,bact2_ep
        jne bact2_lp3
        
        
        ;mov al,2
        mov cx,bact2_x
    
    
    mov bact2_ep,cx
    add bact2_ep,20
    
    
    bact2_lp4:
        int 10h
        inc cx
        cmp cx,bact2_ep
        jne bact2_lp4
        
        add bact2_y,1
        mov dx,bact2_y
        
        cmp dx,480
        jne continue2
        
        mov bact2_y,0
        continue2:     
    popall
    ret     
draw_bact2 endp

;\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\end bact2_draw
;///////////////////////////////////////////////begin bact3_draw

draw_bact3 proc
    pushall    

;bact3_draw:

   
;    mov ah,0
;    mov al,12h
;    int 10h
;    
    
;    mov ah,0ch    
    mov al,4
    mov cx,bact3_x
    mov dx,bact3_y
    
    mov bact3_ep,cx
    add bact3_ep,20
    
    
    bact3_lp1:
    
    int 10h
    inc cx
    cmp cx,bact3_ep
    jne bact3_lp1  
    
    ;mov al,2
    ;mov cx,x
    mov dx,bact3_y
    
    mov bact3_ep,dx
    add bact3_ep,16
    
    
    bact3_lp2:
    
        int 10h
        inc dx
        cmp dx,bact3_ep
        jne bact3_lp2
        
         
        
        ;mov al,2
        mov cx,bact3_x
        mov dx,bact3_y
        
        mov bact3_ep,dx
        add bact3_ep,16
    
    
    bact3_lp3:
        int 10h
        inc dx
        cmp dx,bact3_ep
        jne bact3_lp3
        
        
        ;mov al,2
        mov cx,bact3_x
    
    
    mov bact3_ep,cx
    add bact3_ep,20
    
    
    bact3_lp4:
        int 10h
        inc cx
        cmp cx,bact3_ep
        jne bact3_lp4 
        
        
        add bact3_x,1
        mov dx,bact3_x
        
        cmp dx,640
        jne middle
        
        mov bact3_x,0
        
        middle:
        add bact3_y,1
        mov dx,bact3_y
        
        cmp dx,480
        jne continue3
        
        mov bact3_y,0
        
        continue3:     
    popall
    ret     
draw_bact3 endp

;\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\end bact3_draw

;///////////////////////////////////////////////begin draw_gem
draw_gem proc
    pushall
;gem_draw:

   
;    mov ah,0
;    mov al,12h
;    int 10h
;    
    
;    mov ah,0ch

         
    mov al,9
    mov cx,gem_x
    mov dx,gem_y
    
    mov gem_ep,cx
    add gem_ep,20
    
    
    gem_lp1:
    
    int 10h
    inc cx
    cmp cx,gem_ep
    jne gem_lp1  
    
    mov al,9
    ;mov cx,x
    mov dx,gem_y
    
    mov gem_ep,dx
    add gem_ep,16
    
    
    gem_lp2:
    
        int 10h
        inc dx
        cmp dx,gem_ep
        jne gem_lp2
        
         
        
        mov al,9
        mov cx,gem_x
        mov dx,gem_y
        
        mov gem_ep,dx
        add gem_ep,16
    
    
    gem_lp3:
        int 10h
        inc dx
        cmp dx,gem_ep
        jne gem_lp3
        
        
        mov al,9
        mov cx,gem_x
    
        
        mov gem_ep,cx
        add gem_ep,20
        
    
    gem_lp4:
        int 10h
        inc cx
        cmp cx,gem_ep
        jne gem_lp4 
   
    popall
    ret
draw_gem endp
 

;\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\end draw_gem

;;///////////////////////////////////////////////begin player_draw
;draw_player proc
;    pushall
;    ;player_draw:
;   
;    mov ah,0
;    mov al,12h
;    int 10h
;    
;    
;    mov ah,0ch    
;    mov al,15
;    mov cx,player_x
;    mov dx,player_y
;    
;    mov player_ep,cx
;    add player_ep,20
;    
;    
;    player_lp1:
;    
;    int 10h
;    inc cx
;    cmp cx,player_ep
;    jne player_lp1  
;    
;    mov al,15
;   
;    mov dx,player_y
;    
;    mov player_ep,dx
;    add player_ep,16
;    
;    
;    player_lp2:
;    
;        int 10h
;        inc dx
;        cmp dx,player_ep
;        jne player_lp2
;        
;         
;        
;        mov al,15
;        mov cx,player_x
;        mov dx,player_y
;        
;        mov player_ep,dx
;        add player_ep,16
;    
;    
;    player_lp3:
;        int 10h
;        inc dx
;        cmp dx,player_ep
;        jne player_lp3
;        
;        
;        mov al,15
;        mov cx,player_x
;    
;    
;        mov player_ep,cx
;        add player_ep,20
;    
;    
;    player_lp4:
;        int 10h
;        inc cx
;        cmp cx,player_ep
;        jne player_lp4 
;        
;        
;        mov cx,player_x
;        mov dx,player_y
;        
;        mov al,15
;        
;        add cx,5
;        mov player_ep,dx
;        sub player_ep,10 
;   player_lp5:
;        int 10h
;        dec dx
;        cmp dx,player_ep      ;|up
;        jne player_lp5
;        
;        
;        mov al,15
;        mov player_ep,cx
;        add player_ep,10 
;        
;   player_lp6:
;        int 10h
;        inc cx
;        cmp cx,player_ep       ;|-
;        jne player_lp6
;        
;        mov al,15
;        mov player_ep,dx
;        add player_ep,10
;        
;   player_lp7:
;        int 10h                ;|-| down
;        inc dx                 
;        cmp dx,player_ep     
;        jne player_lp7
;        
;        
;        mov cx,player_x
;        add cx,5
;        
;        mov dx,player_y
;        add dx,16
;        
;        mov player_ep,dx
;        add player_ep,10
;        
;   player_lp8:
;        int 10h
;        inc dx
;        cmp dx,player_ep
;        jne player_lp8
;        
;        add cx,10
;        sub dx,10
;        
;        mov player_ep,dx
;        add player_ep,10
;        
;        
;   player_lp9:
;        int 10h
;        inc dx
;        cmp dx,player_ep
;        jne player_lp9
;        
;        popall
;        ret
;draw_player endp
;;\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\end player_draw
;start:
main proc
    
mov ax, @data
mov ds, ax

    
    start_game:
    

                                    ; Graphic mode
    mov AX,13h
    int 10h

                                    ; Process BMP file
    call OpenFile
    call ReadHeader
    call ReadPalette
    call CopyPal
    call CopyBitmap

                                    ; Wait for key press
    mov ah,1

    int 21h
                                    ; Back to text mode
    mov ah, 0
    mov al, 2
    int 10h
    

 
;======================================================
    jmp player_draw
     
        
jump_to_start:


    
    jmp start_game
;/////////////////////////////////////////drawing player
bact_loop:
    
player_draw:

   
    mov ah,0
    mov al,12h
    int 10h
    
    
    mov ah,0ch    
    mov al,2
    mov cx,player_x
    mov dx,player_y
    
    mov player_ep,cx
    add player_ep,20
    
    
    player_lp1:
    
    int 10h
    inc cx
    cmp cx,player_ep
    jne player_lp1  
    
    mov al,2
   
    mov dx,player_y
    
    mov player_ep,dx
    add player_ep,16
    
    
    player_lp2:
    
        int 10h
        inc dx
        cmp dx,player_ep
        jne player_lp2
        
         
        
        mov al,2
        mov cx,player_x
        mov dx,player_y
        
        mov player_ep,dx
        add player_ep,16
    
    
    player_lp3:
        int 10h
        inc dx
        cmp dx,player_ep
        jne player_lp3
        
        
        mov al,2
        mov cx,player_x
    
    
        mov player_ep,cx
        add player_ep,20
    
    
    player_lp4:
        int 10h
        inc cx
        cmp cx,player_ep
        jne player_lp4 
        
        
        mov cx,player_x
        mov dx,player_y
        
        mov al,15
        
        add cx,5
        mov player_ep,dx
        sub player_ep,10
        
        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
        jmp player_lp5                               
        jump_to_start1:
            jmp jump_to_start
                                           
        
        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; 
   player_lp5:
        int 10h
        dec dx
        cmp dx,player_ep      ;|up
        jne player_lp5
        
        
        mov al,15
        mov player_ep,cx
        add player_ep,10 
        
   player_lp6:
        int 10h
        inc cx
        cmp cx,player_ep       ;|-
        jne player_lp6
        
        mov al,15
        mov player_ep,dx
        add player_ep,10
        
   player_lp7:
        int 10h                ;|-| down
        inc dx                 
        cmp dx,player_ep     
        jne player_lp7
        
        
        mov cx,player_x
        add cx,5
        
        mov dx,player_y
        add dx,16
        
        mov player_ep,dx
        add player_ep,10
        
   player_lp8:
        int 10h
        inc dx
        cmp dx,player_ep
        jne player_lp8
        
        add cx,10
        sub dx,10
        
        mov player_ep,dx
        add player_ep,10
        
        
   player_lp9:
        int 10h
        inc dx
        cmp dx,player_ep
        jne player_lp9
;================================
    call draw_gem
    
    ;call draw_bact1 
    
    call draw_bact2 
    
    call draw_bact3
    ;////////////////////////////////////////////////score and life- message and count 
    
    call score_processing
    call life_processing1
    call life_processing2 
    
    mov dx,life_count
    cmp dx,48
    je jump_to_start2
    ;je score_page
;          
;    ;///////////////////////////////////////////////score page begin
;    ;je score_page
;    
    ;jmp score_msg
;    
;    score_page:
;        
;        mov ah,0
;        mov al,12h
;        int 10h 
;        
;        lea dx,lmsg
;        mov ah,9
;        int 21h
;        
;        mov dx,score_count
;        mov ah,2
;        int 21h
;        
;        
;        mov life_count,53
;        
;        
;        mov ah,0
;        int 16h
;        cmp ah,65
;        jne cont
;        jmp jump_to_start
;        cont:
;    
    ;\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\score page end
    score_msg: 
      lea dx,msg     ;score
      mov ah,9
      int 21h
      
      
      mov dx,score_count    
      mov ah,2
      int 21h 

      ;printNum score_count
      
      lea dx,msg1    ;life
      mov ah,9
      int 21h  
             
      mov dx,life_count
      mov ah,2
      int 21h

       
;////////////////////////////////////////////////score and life end
        
    
    
  ;  sub bact1_x,1
;    add bact2_y,1   

   ; call draw_bact1 
;
;    call draw_bact2
    
    mov ah,1
    int 16h
    jnz key_pressed     

    jmp bact_loop 
    
;=================================
    ;jmp gem_draw 
        
jump_to_start2:
    
    mov ah,0
    mov al,12h
    int 10h
;             

    print lmsg0
    print lmsg1
    print lmsg2
    print lmsg3 
    
    print lmsg0
    print lmsg4
    
    mov dx,score_count ;
    mov ah,2
    int 21h
    
    ;printNum score_count
    
    jmp exit
    ;jmp jump_to_start1
;////////////////////////////////////////////////draw gem
   
;gem_draw:
;    call draw_gem   
;;\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\end gem        

                 
                
                  
                  
                
                 
                
;//////////////////////KEY PRESSED                
    key_pressed: 
                 
                 
                 
                ; 
;                MOV AH,1
;                INT 16H
;                
;                sub bact1_x,1                 
;                mov dx,bact1_x
;                cmp dx,0
;                jne bact1_skip
;                
;                mov bact1_x,620
;                  
;                  
;                bact1_skip:
                       
                
                
                mov  ah,0
                int 16h
                  
          
                cmp ah,48h                       
                je up_key  
                
                cmp ah, 50h
                je down_key
                
                cmp ah,4Bh
                je left_key
                
                cmp ah,4Dh
                je right_key
                
                
             
               left_key:
              
                  sub player_x,10            
                  
                  jmp player_draw  
                                                
               right_key:
                  
                  add player_x,10 
                                    
                  jmp player_draw 
               
               up_key:
                  
                  sub player_y,10
                  
                  jmp player_draw 
               
               down_key:
 
                  add player_y,10
                  
                  jmp player_draw  
               
                
             
               
;======================================================key_pressed end

exit:
    mov ax, 4c00h
    int 21h
    
main endp
end main