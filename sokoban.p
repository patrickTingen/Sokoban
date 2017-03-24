/*
 *  Name : sokoban.p
 *  Desc : play the sokoban game in progress v7+
 *
 *  NOTE:
 *     Original levels of Sokoban were found at http://sokoban-jd.blogspot.nl
 *     Check this fine site for more info on Sokoban and more levels.
 *     Large collection of levels: http://sokoban-jd.blogspot.nl/p/all-my-sokoban-collections.html
 
 *  History:
 *  15 Mar 2000 PT  Created
 *
 */
SESSION:DEBUG-ALERT = TRUE.

DEFINE TEMP-TABLE tt-field NO-UNDO
  FIELD player AS INTEGER
  FIELD X      AS INTEGER
  FIELD Y      AS INTEGER
  FIELD type   AS CHARACTER
  FIELD hnd    AS WIDGET-HANDLE
  FIELD bg     AS LOGICAL
  INDEX tt-field-prim AS PRIMARY player x y.

DEFINE TEMP-TABLE tt-move NO-UNDO
  FIELD player AS INTEGER
  FIELD nr     AS INTEGER
  FIELD dir    AS CHARACTER /* direction */
  FIELD dif-x  AS INTEGER
  FIELD dif-y  AS INTEGER
  FIELD block  AS RECID
  INDEX tt-move AS PRIMARY player nr.

DEFINE TEMP-TABLE tt-level NO-UNDO
  FIELD nr       AS INTEGER
  FIELD filename AS CHARACTER FORMAT 'x(20)'
  FIELD fullname AS CHARACTER FORMAT 'x(20)'
  INDEX tt-level-prim AS PRIMARY filename.

DEFINE VARIABLE window-1           AS WIDGET-HANDLE NO-UNDO.
DEFINE VARIABLE gv-in-block-width  AS INTEGER     NO-UNDO.
DEFINE VARIABLE gv-in-block-height AS INTEGER     NO-UNDO.
DEFINE VARIABLE gv-in-move         AS INTEGER     NO-UNDO.
DEFINE VARIABLE gv-in-level        AS INTEGER     NO-UNDO INITIAL 1.
DEFINE VARIABLE gv-ch-level-dir    AS CHARACTER   NO-UNDO.
DEFINE VARIABLE gv-in-x            AS INTEGER     NO-UNDO.
DEFINE VARIABLE gv-in-y            AS INTEGER     NO-UNDO.
DEFINE VARIABLE gv-lo-completed    AS LOGICAL     NO-UNDO.
DEFINE VARIABLE player             AS WIDGET-HANDLE NO-UNDO.

DEFINE FRAME FRAME-A
WITH
  1 DOWN NO-BOX OVERLAY SIDE-LABELS NO-UNDERLINE COLOR blue/white
  THREE-D AT COL 1 ROW 1 SIZE 82 BY 15.

CREATE WINDOW WINDOW-1
TRIGGERS:
  ON WINDOW-RESIZED DO:
    RUN calculate-dimensions ( INPUT FRAME frame-a:HANDLE, INPUT YES ).
    RUN draw-buttons ( INPUT 1, INPUT FRAME frame-a:HANDLE, INPUT YES, INPUT 0, INPUT 0 ).
    RUN draw-player.
  END.
  
  ON WINDOW-CLOSE 
  DO:
    /* This event will close the window and terminate the procedure.  */
    APPLY "CLOSE":U TO THIS-PROCEDURE.
    RETURN NO-APPLY.
  END.
END TRIGGERS.


/* Menu Definitions */
DEFINE SUB-MENU m_file /* file */
  MENU-ITEM m_i2 LABEL "&Exit".
       
DEFINE SUB-MENU m_level /* level */
  MENU-ITEM mi_undo LABEL "&Undo move"
  MENU-ITEM mi_redo LABEL "&Redo move".
  RULE
  MENU-ITEM mi_restart LABEL "&Restart level"
  MENU-ITEM mi_first   LABEL "&First level".
  MENU-ITEM mi_next    LABEL "&Next level".
  MENU-ITEM mi_prev    LABEL "&Previous level".
  MENU-ITEM mi_any     LABEL "&Goto level".

DEFINE MENU MENU-BAR-WINDOW-1 MENUBAR
  SUB-MENU  m_file  LABEL "&File"            
  SUB-MENU  m_level LABEL "&Level".

ON CHOOSE OF MENU-ITEM mi_undo IN MENU m_level
DO:
  IF NOT gv-lo-completed THEN RUN process-undo(1).
END.

ON CHOOSE OF MENU-ITEM mi_redo IN MENU m_level
DO:
  IF NOT gv-lo-completed THEN RUN process-redo(1).
END.

ON CHOOSE OF MENU-ITEM m_i2 IN MENU m_file
  APPLY 'close' TO THIS-PROCEDURE.

ON CHOOSE OF MENU-ITEM mi_restart IN MENU m_level
  RUN restart-level.

ON CHOOSE OF MENU-ITEM mi_first IN MENU m_level
  RUN first-level.

ON CHOOSE OF MENU-ITEM mi_next IN MENU m_level
  RUN next-level.

ON CHOOSE OF MENU-ITEM mi_prev IN MENU m_level
  RUN prev-level.

ON CHOOSE OF MENU-ITEM mi_any IN MENU m_level
  RUN browse-for-level.

RUN initialize.

CREATE BUTTON player /* button widget */
   ASSIGN
     ROW       = 3
     COLUMN    = 5
     LABEL     = "X"
     FRAME     = FRAME frame-a:HANDLE
     SENSITIVE = TRUE
     VISIBLE   = TRUE.

ON any-key ANYWHERE 
  DO:
    IF LASTKEY EQ 32 
      AND NOT gv-lo-completed THEN RUN process-redo(1).
  END.

ON CURSOR-LEFT ANYWHERE
  DO: 
    IF gv-lo-completed THEN RETURN NO-APPLY.
    RUN process-keystroke ( 'left',  OUTPUT gv-lo-completed ).
    IF gv-lo-completed THEN RUN completed.
  END.

ON CURSOR-UP ANYWHERE
  DO:
    IF gv-lo-completed THEN RETURN NO-APPLY.
    RUN process-keystroke ( 'up',    OUTPUT gv-lo-completed ).
    IF gv-lo-completed THEN RUN completed.
  END.

ON CURSOR-RIGHT ANYWHERE 
  DO:
    IF gv-lo-completed THEN RETURN NO-APPLY.
    RUN process-keystroke ( 'right', OUTPUT gv-lo-completed ).
    IF gv-lo-completed THEN RUN completed.
  END.

ON CURSOR-DOWN ANYWHERE
  DO:
    IF gv-lo-completed THEN RETURN NO-APPLY.
    RUN process-keystroke ( 'down',  OUTPUT gv-lo-completed ).
    IF gv-lo-completed THEN RUN completed.
  END.

ON BACKSPACE ANYWHERE
  DO:
    IF gv-lo-completed THEN RETURN NO-APPLY.
    RUN process-undo(1). 
  END.
  
RUN read-level-from-file ( INPUT gv-in-level, INPUT 1, INPUT FRAME FRAME-A:HANDLE ).
APPLY "window-resized" TO window-1.

WAIT-FOR CLOSE OF THIS-PROCEDURE FOCUS player.


PROCEDURE completed:
  /* Level has been completed, congratulate and ask to proceed.
  */
  DEFINE VARIABLE lv-lo-ok   AS LOGICAL NO-UNDO INITIAL TRUE.
  DEFINE VARIABLE lv-ch-file AS CHARACTER   NO-UNDO.

  /* Check if solution has already been recorded. */
  ASSIGN
    lv-ch-file = gv-ch-level-dir + 'level' + STRING(gv-in-level,'999') + '.sol'.
  
  /* Check if file exists */
  IF SEARCH(lv-ch-file) EQ ? THEN 
  DO:
    OUTPUT TO VALUE( lv-ch-file ).
    FOR EACH tt-move WHERE tt-move.player = 1:
      EXPORT tt-move.
    END.
    OUTPUT CLOSE.
  END.

  MESSAGE 
    "Congratulations, you have completed level" gv-in-level "in" gv-in-move " moves." SKIP(1)
    "Would you like to proceed to the next level?"
  VIEW-AS ALERT-BOX QUESTION BUTTONS YES-NO UPDATE lv-lo-ok.
  
  IF NOT lv-lo-ok THEN 
    MESSAGE "OK, suit yourself." VIEW-AS ALERT-BOX INFO.
  ELSE 
  DO:
    gv-in-level = gv-in-level + 1.
    RUN start-level.
  END.
 
END PROCEDURE. /* completed */


PROCEDURE start-level:
  /* Start a level
  */
  ASSIGN
    gv-lo-completed = FALSE
    gv-in-move      = 0.
      
  RUN read-level-from-file ( INPUT gv-in-level, INPUT 1, INPUT FRAME FRAME-A:HANDLE ).
  RUN calculate-dimensions ( INPUT FRAME frame-a:HANDLE, INPUT YES ).
  RUN draw-buttons ( INPUT 1, INPUT FRAME frame-a:HANDLE, INPUT YES, INPUT 0, INPUT 0 ).
  RUN draw-player.
END PROCEDURE. /* start-level */


PROCEDURE restart-level:
  /* Restart current level
  */
  DEFINE VARIABLE lv-lo-restart AS LOGICAL NO-UNDO INITIAL YES.
  IF gv-in-move > 0 THEN 
  MESSAGE 'Are you sure you want to restart the level?'
    VIEW-AS ALERT-BOX QUESTION BUTTONS YES-NO-CANCEL UPDATE lv-lo-restart.
  IF lv-lo-restart THEN RUN start-level.
END PROCEDURE. /* restart-level */


PROCEDURE first-level:
  /* goto the first level
  */
  DEFINE VARIABLE lv-lo-restart AS LOGICAL NO-UNDO INITIAL YES.

  IF gv-in-move > 0 THEN 
  MESSAGE 'Are you sure you want to start with the first level?'
    VIEW-AS ALERT-BOX QUESTION BUTTONS YES-NO-CANCEL UPDATE lv-lo-restart.

  IF lv-lo-restart THEN
  DO:
    ASSIGN gv-in-level = 1.
    RUN start-level.
  END.
END PROCEDURE. /* first-level */


PROCEDURE next-level:
  /* Goto next level
  */
  DEFINE VARIABLE lv-lo-restart AS LOGICAL NO-UNDO INITIAL YES.

  IF gv-in-move > 0 THEN 
  MESSAGE 'Are you sure you want to proceed to the next level?'
    VIEW-AS ALERT-BOX QUESTION BUTTONS YES-NO-CANCEL UPDATE lv-lo-restart.

  IF lv-lo-restart THEN
  DO:
    ASSIGN gv-in-level = gv-in-level + 1.
    RUN start-level.
  END.
END PROCEDURE. /* next-level */


PROCEDURE prev-level:
  /* Goto previous level
  */
  DEFINE VARIABLE lv-lo-restart AS LOGICAL NO-UNDO INITIAL YES.

  IF gv-in-level EQ 1 THEN
  DO:
    MESSAGE 'You already are at the first level.'
      VIEW-AS ALERT-BOX INFO.
    RETURN.
  END.

  IF gv-in-move > 0 THEN 
  MESSAGE 'Are you sure you want to go back to the previous level?'
    VIEW-AS ALERT-BOX QUESTION BUTTONS YES-NO-CANCEL UPDATE lv-lo-restart.

  IF lv-lo-restart THEN
  DO:
    ASSIGN gv-in-level = gv-in-level - 1.
    RUN start-level.
  END.
END PROCEDURE. /* prev-level */


PROCEDURE initialize:
  /* Initialize variables and calculate block width and height.
  */
  ASSIGN
    FRAME frame-a:HEIGHT-CHARS = 24
    FRAME frame-a:WIDTH-CHARS  = 78.

  ASSIGN
    window-1:TITLE              = "Sokoban"
    window-1:COLUMN             = 10
    window-1:ROW                = 6
    window-1:HEIGHT             = 30
    window-1:WIDTH              = 100
    window-1:MAX-HEIGHT         = 220
    window-1:MAX-WIDTH          = 220
    window-1:VIRTUAL-HEIGHT     = 220
    window-1:VIRTUAL-WIDTH      = 220
    window-1:RESIZE             = yes
    window-1:SCROLL-BARS        = no
    window-1:STATUS-AREA        = no
    window-1:BGCOLOR            = ?
    window-1:FGCOLOR            = ?
    window-1:THREE-D            = yes
    window-1:MESSAGE-AREA       = no
    window-1:SENSITIVE          = yes
    window-1:HIDDEN             = NO.
    window-1:MENUBAR            = MENU MENU-BAR-WINDOW-1:HANDLE.

  ASSIGN
    gv-lo-completed = FALSE
    gv-in-move      = 0.
   
  THIS-PROCEDURE:CURRENT-WINDOW = window-1.

  /* Where are we running from? */
  FILE-INFO:FILE-NAME = THIS-PROCEDURE:FILE-NAME.
  gv-ch-level-dir = REPLACE(FILE-INFO:FULL-PATHNAME,"\","/").
  gv-ch-level-dir = SUBSTRING(gv-ch-level-dir,1,R-INDEX(gv-ch-level-dir,'/')) + 'levels/'.

END PROCEDURE. /* initialize */


PROCEDURE read-level-from-file:
  /* Read a level from an ascii file and put it in the temp-table.
  */
  DEFINE INPUT PARAMETER ip-in-level  AS INTEGER   NO-UNDO.
  DEFINE INPUT PARAMETER ip-in-player AS INTEGER   NO-UNDO.
  DEFINE INPUT PARAMETER ip-wh-parent AS WIDGET-HANDLE NO-UNDO.

  DEFINE VARIABLE lv-ch-file    AS CHARACTER   NO-UNDO.
  DEFINE VARIABLE lv-in-x       AS INTEGER     NO-UNDO.
  DEFINE VARIABLE lv-in-y       AS INTEGER     NO-UNDO.
  DEFINE VARIABLE lv-ch-line    AS CHARACTER   NO-UNDO.
  DEFINE VARIABLE lv-ch-element AS CHARACTER   NO-UNDO.
  DEFINE VARIABLE lv-in-min-x   AS INTEGER INITIAL 20 NO-UNDO.
  DEFINE VARIABLE lv-in-max-x   AS INTEGER INITIAL 0  NO-UNDO.
  DEFINE VARIABLE lv-in-min-y   AS INTEGER INITIAL 20 NO-UNDO.
  DEFINE VARIABLE lv-in-max-y   AS INTEGER INITIAL 0  NO-UNDO.

  /*
  ** Layout sokoban XSB-file:
  **
  ** Levelsize max 20 x 20 blocks
  ** Signs: @ = player  $ = box          * = box on targetplace
  **        # = wall    . = targetplace  + = player on targetplace
  **
  ** Example:
  **       #########
  **      ##   ##  #####
  **    ###     #  #    ###
  **    #  $ #$ #  #  ... #
  **    # # $#@$## # #.#. #
  **    #  # #$  #    . . #
  **    # $    $ # # #.#. #
  **    #   ##  ##$ $ . . #
  **    # $ #   #  #$#.#. #
  **    ## $  $   $  $... #
  **     #$ ######    ##  #
  **     #  #    ##########
  **     ####
  */

  /* Determine filename. */
  ASSIGN 
    lv-ch-file = gv-ch-level-dir + 'level' + STRING(ip-in-level,'999') + '.xsb'.
    
  IF SEARCH(lv-ch-file) EQ ? THEN
  DO:
    MESSAGE "File for level" ip-in-level "not found." VIEW-AS ALERT-BOX ERROR.
    RETURN.
  END.  
    
  /* Clear the temp-table */
  FOR EACH tt-field WHERE tt-field.player EQ ip-in-player:
    DELETE OBJECT tt-field.hnd NO-ERROR.
    DELETE tt-field.
  END.

  /* Clear the move-table */
  FOR EACH tt-move WHERE tt-move.player EQ ip-in-player:
    DELETE tt-move.
  END.
  
  /* Hide the player */
  IF ip-in-player NE 0 THEN
    ASSIGN player:VISIBLE = FALSE.

  INPUT FROM VALUE( lv-ch-file ).

  /* max 20 blocks high */
  REPEAT lv-in-y = 1 TO 20:
    IMPORT UNFORMATTED lv-ch-line.

    /* max 20 blocks wide */
    DO lv-in-x = 1 TO 20:
      ASSIGN lv-ch-element = SUBSTRING(lv-ch-line,lv-in-x,1).
      IF lv-ch-element EQ ' ' THEN NEXT.

      /* element found */
      CASE lv-ch-element:
        /* player */
        WHEN '@' THEN ASSIGN
                        gv-in-x = lv-in-x
                        gv-in-y = lv-in-y.
        /* player on targetplace */
        WHEN '+' THEN DO:
                        ASSIGN
                          gv-in-x = lv-in-x
                          gv-in-y = lv-in-y.
                        RUN create-field('target',ip-wh-parent,ip-in-player,lv-in-x,lv-in-y).
                      END.
        /* block */
        WHEN '$' THEN RUN create-field('block',ip-wh-parent,ip-in-player,lv-in-x,lv-in-y).
        /* wall */
        WHEN '#' THEN RUN create-field('wall',ip-wh-parent,ip-in-player,lv-in-x,lv-in-y).
        /* target */
        WHEN '.' THEN RUN create-field('target',ip-wh-parent,ip-in-player,lv-in-x,lv-in-y).
        /* block on targetplace */
        WHEN '*' THEN DO:
                        RUN create-field('block',ip-wh-parent,ip-in-player,lv-in-x,lv-in-y).
                        RUN create-field('target',ip-wh-parent,ip-in-player,lv-in-x,lv-in-y).
                      END.
      END CASE. /* lv-ch-element */

      /* Maintain highest and lowest values for x and y
      ** to center the field horizontally and vertically */
      ASSIGN
        lv-in-min-x = MINIMUM( lv-in-min-x, tt-field.x)
        lv-in-max-x = MAXIMUM( lv-in-max-x, tt-field.x)
        lv-in-min-y = MINIMUM( lv-in-min-y, tt-field.y)
        lv-in-max-y = MAXIMUM( lv-in-max-y, tt-field.y).

    END. /* lv-in-x */
  END. /* gc-in-y */
  INPUT CLOSE.


  /* Center the level. */
  FOR EACH tt-field
    WHERE tt-field.player EQ ip-in-player BY RECID( tt-field ):
    ASSIGN 
      tt-field.x = tt-field.x + ROUND((20 - ( lv-in-max-x - lv-in-min-x + 1 )) / 2,0)
      tt-field.y = tt-field.y + ROUND((20 - ( lv-in-max-y - lv-in-min-y + 1 )) / 2,0).
  END.
  
  /* Adjust player start position. */
  IF ip-in-player NE 0 THEN
  DO:
    ASSIGN
      gv-in-x = gv-in-x + ROUND((20 - ( lv-in-max-x - lv-in-min-x + 1 )) / 2,0)
      gv-in-y = gv-in-y + ROUND((20 - ( lv-in-max-y - lv-in-min-y + 1 )) / 2,0).

    ASSIGN player:VISIBLE = TRUE.
    ASSIGN window-1:TITLE = 'Sokoban level ' + STRING( gv-in-level ).
  END.
  
END PROCEDURE. /* read-level-from-file */


PROCEDURE create-field:
  /* Create a field in the tt for an element on the board.
  */
  DEFINE INPUT PARAMETER ip-ch-type   AS CHARACTER    NO-UNDO.
  DEFINE INPUT PARAMETER ip-wh-parent AS WIDGET-HANDLE NO-UNDO.
  DEFINE INPUT PARAMETER ip-in-player AS INTEGER      NO-UNDO.
  DEFINE INPUT PARAMETER ip-in-x      AS INTEGER      NO-UNDO.
  DEFINE INPUT PARAMETER ip-in-y      AS INTEGER      NO-UNDO.

  /* create a record for each element */
  CREATE tt-field.
  ASSIGN tt-field.player = ip-in-player
         tt-field.X      = ip-in-x
         tt-field.Y      = ip-in-y
         tt-field.TYPE   = ip-ch-type.

  /* create a rectangle for each element */
  CREATE RECTANGLE tt-field.hnd  /* RECTANGLE widget */
  ASSIGN
    FRAME     = ip-wh-parent
    SENSITIVE = FALSE
    VISIBLE   = FALSE
    FILLED    = TRUE .

  CASE tt-field.type:
    WHEN "wall"   THEN ASSIGN tt-field.hnd:FGCOLOR = 14
                              tt-field.hnd:BGCOLOR = 1
                              tt-field.bg          = NO.

    WHEN "block"  THEN ASSIGN tt-field.hnd:FGCOLOR = 14
                              tt-field.hnd:BGCOLOR = 6
                              tt-field.bg          = NO.

    WHEN "target" THEN ASSIGN tt-field.hnd:FGCOLOR = 14
                              tt-field.hnd:BGCOLOR = 8
                              tt-field.bg          = YES.
  END CASE.
END PROCEDURE. /* create-field */


PROCEDURE draw-buttons:
  /* Draw the buttons of the level according to current sizes.
  */
  DEFINE INPUT PARAMETER ip-in-player     AS INTEGER       NO-UNDO.
  DEFINE INPUT PARAMETER ip-wh-parent     AS WIDGET-HANDLE NO-UNDO.
  DEFINE INPUT PARAMETER ip-lo-hideparent AS LOGICAL       NO-UNDO.
  DEFINE INPUT PARAMETER ip-in-offset-x   AS INTEGER       NO-UNDO.
  DEFINE INPUT PARAMETER ip-in-offset-y   AS INTEGER       NO-UNDO.

  DEFINE VARIABLE lv-hn-block AS HANDLE      NO-UNDO.

  IF ip-lo-hideparent THEN
    ASSIGN ip-wh-parent:HIDDEN = YES.

  FOR EACH tt-field
    WHERE tt-field.player EQ ip-in-player:
    ASSIGN tt-field.hnd:VISIBLE = FALSE.
  END. /* for each tt-field */

  FOR EACH tt-field
    WHERE tt-field.player EQ ip-in-player:
    RUN draw-element ( INPUT RECID( tt-field ), INPUT NO,
                       INPUT ip-in-offset-x, INPUT ip-in-offset-y ).
  END. /* for each tt-field */

  FOR EACH tt-field
    WHERE tt-field.player EQ ip-in-player:
    ASSIGN tt-field.hnd:VISIBLE = TRUE.
  END. /* for each tt-field */

  IF ip-lo-hideparent THEN
    ASSIGN ip-wh-parent:HIDDEN = NO.
END PROCEDURE. /* draw-buttons */


PROCEDURE draw-element:
  /* Draw a single element.
  */
  DEFINE INPUT PARAMETER ip-re-element      AS RECID.
  DEFINE INPUT PARAMETER ip-lo-make-visible AS LOGICAL.
  DEFINE INPUT PARAMETER ip-in-offset-x     AS INTEGER     NO-UNDO.
  DEFINE INPUT PARAMETER ip-in-offset-y     AS INTEGER     NO-UNDO.

  FIND tt-field WHERE RECID(tt-field) EQ ip-re-element.

  IF ip-lo-make-visible THEN
    ASSIGN
      tt-field.hnd:VISIBLE = FALSE.

  ASSIGN 
    tt-field.hnd:x             = ( tt-field.X - 1) * gv-in-block-width + 1 + ip-in-offset-x
    tt-field.hnd:Y             = ( tt-field.Y - 1) * gv-in-block-height + 1 + ip-in-offset-y
    tt-field.hnd:WIDTH-PIXELS  = gv-in-block-width
    tt-field.hnd:HEIGHT-PIXELS = gv-in-block-height.

  IF ip-lo-make-visible THEN
    ASSIGN
      tt-field.hnd:VISIBLE = TRUE.

END PROCEDURE. /* draw-element */


PROCEDURE move-block:
  /* Move a block and check if it is placed on a target field.
  */
  DEFINE INPUT PARAMETER ip-re-block AS RECID.
  DEFINE INPUT PARAMETER ip-in-dif-x AS INTEGER.
  DEFINE INPUT PARAMETER ip-in-dif-y AS INTEGER.
  
  DEFINE BUFFER t2-field FOR tt-field.
  
  FIND tt-field WHERE RECID(tt-field) EQ ip-re-block.
  
  /* check if a block was on a target. If so, make the target visible */
  FIND t2-field 
    WHERE t2-field.player EQ tt-field.player
      AND t2-field.x      EQ tt-field.x
      AND t2-field.y      EQ tt-field.y
      AND t2-field.type   EQ 'target'
          NO-ERROR.
  IF AVAILABLE t2-field THEN t2-field.hnd:visible = TRUE.

  /* move the block */
  ASSIGN
    tt-field.x = tt-field.x + ip-in-dif-x
    tt-field.y = tt-field.y + ip-in-dif-y.
    
  /* draw block */
  RUN draw-element ( INPUT ip-re-block,
                     INPUT YES,
                     INPUT 0,
                     INPUT 0 ).

  /* check if a block is moved onto a target. If so, make the target invisible */
  FIND t2-field 
    WHERE t2-field.player EQ tt-field.player
      AND t2-field.x      EQ tt-field.x
      AND t2-field.y      EQ tt-field.y
      AND t2-field.type   EQ 'target'
          NO-ERROR.
  IF AVAILABLE t2-field THEN t2-field.hnd:visible = FALSE.
  
END PROCEDURE. /* move-block */


PROCEDURE draw-player:
  /* Draw the player
  */
  DO WITH FRAME frame-a:
    /* place the player */
    ASSIGN
      player:VISIBLE       = FALSE
      player:x             = ( gv-in-x - 1) * gv-in-block-width + 1
      player:Y             = ( gv-in-y - 1) * gv-in-block-height + 1
      player:WIDTH-PIXELS  = gv-in-block-width
      player:HEIGHT-PIXELS = gv-in-block-height
      player:VISIBLE       = TRUE.
  END.
  
  /* debug */
  player:LABEL = STRING(gv-in-move).
  
END PROCEDURE. /* draw-player */


PROCEDURE calculate-dimensions:
  /* Calculate dimensions of frame and buttons, based on parent window.
  */
  DEFINE INPUT PARAMETER ip-wh-parent AS WIDGET-HANDLE  NO-UNDO.
  DEFINE INPUT PARAMETER ip-lo-adjust AS LOGICAL        NO-UNDO.

  /* Adjust frame to fit in window */
  ip-wh-parent:HIDDEN = YES.
  IF ip-lo-adjust THEN
    ASSIGN
      ip-wh-parent:WIDTH-PIXELS  = window-1:WIDTH-PIXELS
      ip-wh-parent:HEIGHT-PIXELS = window-1:HEIGHT-PIXELS
      .
      
  /* Calculate new size for buttons. */
  ASSIGN
    gv-in-block-width  = TRUNC(ip-wh-parent:WIDTH-PIXELS  / 21,0)
    gv-in-block-height = TRUNC(ip-wh-parent:HEIGHT-PIXELS / 21,0).

END PROCEDURE. /* calculate-dimensions */


PROCEDURE process-keystroke:
  /* Check if the keystroke is a legal move and if the game is completed.
  */
  DEFINE INPUT  PARAMETER ip-ch-keystroke AS CHARACTER   NO-UNDO.
  DEFINE OUTPUT PARAMETER op-lo-completed AS LOGICAL     NO-UNDO.

  DEFINE BUFFER t2-field FOR tt-field.
  DEFINE BUFFER t2-move  FOR tt-move.

  DEFINE VARIABLE lv-lo-valid-move AS LOGICAL INITIAL ?  NO-UNDO.
  DEFINE VARIABLE lv-in-new-x      AS INTEGER     NO-UNDO.
  DEFINE VARIABLE lv-in-new-y      AS INTEGER     NO-UNDO.

  /* Delete 'future' moves in case the player undoes a number of moves,
  ** redoes some of the undone moves and before he has redone all undone
  ** moves, he gives new keystrokes. All moves which at that point have not
  ** been redone, will be deleted. 
  */
  FOR EACH tt-move
    WHERE tt-move.player EQ 1
      AND tt-move.nr     GT gv-in-move:
    DELETE tt-move.
  END.
  
  /* Register the move. */
  CREATE tt-move.
  ASSIGN gv-in-move     = gv-in-move + 1
         tt-move.player = 1
         tt-move.nr     = gv-in-move
         tt-move.dir    = ip-ch-keystroke.
  
  /* Calculate steps */
  CASE ip-ch-keystroke:
    WHEN 'up'    THEN ASSIGN tt-move.dif-y = -1.
    WHEN 'down'  THEN ASSIGN tt-move.dif-y = 1.
    WHEN 'right' THEN ASSIGN tt-move.dif-x = 1.
    WHEN 'left'  THEN ASSIGN tt-move.dif-x = -1.
  END CASE.

  /* Calculate new position */
  ASSIGN
    lv-in-new-x = gv-in-x + tt-move.dif-x
    lv-in-new-y = gv-in-y + tt-move.dif-y.

  /* Check if move is allowed. Determine wether the position the player
  ** wants to go to is a blank place. In that case, the keystroke need
  ** no further processing.
  */
  FIND tt-field
    WHERE tt-field.player EQ 1
      AND tt-field.X      EQ lv-in-new-x
      AND tt-field.Y      EQ lv-in-new-y
      AND tt-field.bg     EQ FALSE
          NO-ERROR.
          
  IF NOT AVAILABLE tt-field THEN
    ASSIGN lv-lo-valid-move = TRUE.
  ELSE
  DO:
    /* So, not a blank place. Check if it is a block and if the block can be moved
    ** by checking if the place beneath the block is a blank one.
    */
    IF tt-field.type = 'block'
      AND NOT CAN-FIND(tt-field
                 WHERE tt-field.player EQ 1
                   AND tt-field.X      EQ lv-in-new-x + tt-move.dif-x
                   AND tt-field.Y      EQ lv-in-new-y + tt-move.dif-y
                   AND tt-field.bg     EQ FALSE ) THEN
    DO:
      RUN move-block ( RECID(tt-field), tt-move.dif-x, tt-move.dif-y ).    
      ASSIGN lv-lo-valid-move = TRUE.
    
      /* Register the move of the block */
      ASSIGN tt-move.block = RECID(tt-field).
       
    END. /* block */
    ELSE
      ASSIGN lv-lo-valid-move = FALSE.
  END.

  /* if the move is valid, move the player to the right place */
  IF lv-lo-valid-move THEN
  DO WITH FRAME frame-a:
    ASSIGN
      gv-in-x = lv-in-new-x
      gv-in-y = lv-in-new-y.
    RUN draw-player.
  END.
  ELSE
  DO:
    DELETE tt-move. /* otherwise cancel the move */
    ASSIGN gv-in-move = gv-in-move - 1.
  END.

  /* 
  ** Check if the level has been completed.
  */
  FIND FIRST tt-field
    WHERE tt-field.player EQ 1
      AND tt-field.type   EQ  'block'
      AND NOT CAN-FIND ( t2-field WHERE t2-field.player EQ 1
                                    AND t2-field.x      EQ tt-field.x
                                    AND t2-field.y      EQ tt-field.y
                                    AND t2-field.type   EQ 'target' ) NO-ERROR.
  ASSIGN op-lo-completed = NOT ( AVAILABLE tt-field ).
    
END PROCEDURE. /* process-keystroke */


PROCEDURE process-undo:
  /* Undo the last move.
  */
  DEFINE INPUT PARAMETER ip-in-player AS INTEGER   NO-UNDO.

  FIND tt-move
    WHERE tt-move.player EQ ip-in-player
      AND tt-move.nr     EQ gv-in-move
          NO-ERROR.
  IF NOT AVAILABLE tt-move THEN RETURN.
  ASSIGN gv-in-move = gv-in-move - 1.
  
  /* Move the player */
  DO WITH FRAME frame-a:
    ASSIGN
      gv-in-x = gv-in-x - tt-move.dif-x
      gv-in-y = gv-in-y - tt-move.dif-y.
    RUN draw-player.
  END.

  /* If a block was moved, move it back. */
  IF tt-move.block NE ? THEN 
    RUN move-block ( tt-move.block, tt-move.dif-x * -1, tt-move.dif-y * -1).    

END PROCEDURE. /* process-undo */


PROCEDURE process-redo:
  /* Redo the next move in the tt-move table
  */
  DEFINE INPUT PARAMETER ip-in-player AS INTEGER   NO-UNDO.
  
  DEFINE VARIABLE lv-in-dif-x      AS INTEGER     NO-UNDO.
  DEFINE VARIABLE lv-in-dif-y      AS INTEGER     NO-UNDO.

  DEFINE BUFFER t2-field FOR tt-field.

  FIND tt-move
    WHERE tt-move.player EQ ip-in-player
      AND tt-move.nr     EQ gv-in-move + 1
          NO-ERROR.
  IF NOT AVAILABLE tt-move THEN RETURN.
  ASSIGN gv-in-move = gv-in-move + 1.
  
  /* Calculate new coordinates. */
  CASE tt-move.dir:
    WHEN 'up'    THEN ASSIGN lv-in-dif-y = -1.
    WHEN 'down'  THEN ASSIGN lv-in-dif-y = 1.
    WHEN 'right' THEN ASSIGN lv-in-dif-x = 1.
    WHEN 'left'  THEN ASSIGN lv-in-dif-x = -1.
  END CASE.
  
  /* Move the player */
  DO WITH FRAME frame-a:
    ASSIGN
      gv-in-x = gv-in-x + lv-in-dif-x
      gv-in-y = gv-in-y + lv-in-dif-y.
    RUN draw-player.
  END.

  /* If a block was moved, move it back. */
  IF tt-move.block NE ? THEN 
    RUN move-block ( tt-move.block, lv-in-dif-x, lv-in-dif-y).    

END PROCEDURE. /* process-redo */


PROCEDURE browse-for-level:
  /* browse for a level in the dir with levels.
  */
  DEFINE VARIABLE lv-ch-filename     AS CHARACTER   NO-UNDO.
  DEFINE VARIABLE lv-ch-fullname     AS CHARACTER   NO-UNDO.
  DEFINE VARIABLE lv-in-block-width  AS INTEGER     NO-UNDO.
  DEFINE VARIABLE lv-in-block-height AS INTEGER     NO-UNDO.
  DEFINE VARIABLE lv-in-x-old        AS INTEGER     NO-UNDO.
  DEFINE VARIABLE lv-in-y-old        AS INTEGER     NO-UNDO.
  
  /* save old blocksizes */
  ASSIGN
    lv-in-block-width  = gv-in-block-width
    lv-in-block-height = gv-in-block-height
    lv-in-x-old        = gv-in-x
    lv-in-y-old        = gv-in-y
    .

  FOR EACH tt-level:
    DELETE tt-level.
  END.

  INPUT FROM OS-DIR ( gv-ch-level-dir ).
  REPEAT:
    IMPORT lv-ch-filename lv-ch-fullname.
    IF NOT lv-ch-filename MATCHES '*~~.xsb' THEN NEXT.
    CREATE tt-level.
    ASSIGN tt-level.nr       = INTEGER(SUBSTRING(lv-ch-filename,6,3))
           tt-level.filename = lv-ch-filename
           tt-level.fullname = lv-ch-fullname.
  END.
  INPUT CLOSE.

  /* Definitions of the field level widgets */
  DEFINE VARIABLE EDITOR-1 AS CHARACTER
    VIEW-AS EDITOR NO-WORD-WRAP SCROLLBAR-HORIZONTAL SCROLLBAR-VERTICAL
    SIZE 42 BY 13 FONT 2 NO-UNDO.

  /* Query definitions */
  DEFINE QUERY BROWSE-1 FOR tt-level SCROLLING.

  /* Browse definitions */
  DEFINE BROWSE BROWSE-1 QUERY BROWSE-1 NO-LOCK DISPLAY
    tt-level.filename WITH SIZE 30 BY 13.

  DEFINE BUTTON BUTTON-1 LABEL "Choose" SIZE 9.72 BY 1.08.
  DEFINE BUTTON BUTTON-2 AUTO-END-KEY LABEL "Cancel" SIZE 9.72 BY 1.08.

  DEFINE FRAME DIALOG-1
    BROWSE-1 AT ROW 2 COL 6
    BUTTON-1 AT ROW 16 COL 6
    BUTTON-2 AT ROW 16 COL 17
    WITH VIEW-AS DIALOG-BOX KEEP-TAB-ORDER SIZE 100 BY 18
    SIDE-LABELS NO-UNDERLINE THREE-D SCROLLABLE TITLE "Choose a level".

  ASSIGN FRAME DIALOG-1:SCROLLABLE = FALSE.

  ON VALUE-CHANGED OF BROWSE-1 IN FRAME DIALOG-1
  DO:
    RUN read-level-from-file ( INPUT tt-level.nr, INPUT 0, INPUT FRAME DIALOG-1:HANDLE ).
    RUN draw-buttons ( INPUT 0, INPUT FRAME dialog-1:HANDLE, INPUT NO, INPUT 200, INPUT 0 ).
  END.
  
  ON DEFAULT-ACTION OF BROWSE-1 IN FRAME DIALOG-1
    APPLY 'choose' TO button-1.

  ON CHOOSE OF button-1
  DO:
    DEFINE VARIABLE lv-in-level AS INTEGER.
    ASSIGN lv-in-level = INTEGER(SUBSTRING(tt-level.FILENAME,6,3)) NO-ERROR.
    IF NOT ERROR-STATUS:ERROR THEN
    DO:
      ASSIGN gv-in-level = lv-in-level.
      RUN start-level.
      APPLY 'go' TO FRAME dialog-1.
    END.
  END.

  ON WINDOW-CLOSE OF FRAME dialog-1 APPLY "END-ERROR" TO SELF. 

  DO ON ERROR   UNDO , LEAVE
     ON END-KEY UNDO , LEAVE :

    ENABLE BROWSE-1 button-1 button-2 WITH FRAME DIALOG-1.
    RUN calculate-dimensions ( INPUT FRAME dialog-1:HANDLE, INPUT no ).
    gv-in-block-width  = gv-in-block-width * 0.6.

    OPEN QUERY BROWSE-1 FOR EACH tt-level NO-LOCK.
    APPLY 'value-changed' TO browse-1.
    WAIT-FOR GO OF FRAME dialog-1.
  END.

  /* restore old blocksizes */
  ASSIGN
    gv-in-block-width  = lv-in-block-width
    gv-in-block-height = lv-in-block-height
    gv-in-x = lv-in-x-old.
    gv-in-y = lv-in-y-old.
    .

END PROCEDURE. /* browse-for-level */
