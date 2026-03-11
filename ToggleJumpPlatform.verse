using { /Verse.org/SceneGraph }
using { /Verse.org/Simulation }
using { /Verse.org/SpatialMath }
using { /Verse.org/SceneGraph/KeyframedMovement }
using { /Fortnite.com/Characters }
using { /Fortnite.com/Playspaces }
using { /Fortnite.com/Game }

toggle_jump_platform_component := class<final_super>(component):
    @editable
    Duration:float = 0.5
    @editable
    Flip:rotation = rotation{}

    var MovementComponent:keyframed_movement_component = keyframed_movement_component{Entity := entity{}}
    var JumpedEventMap:[player]cancelable = map{}
    var IsFlipped:logic = false
    var IsMoving:logic = false

    Toggle()<suspends>:void=
        if(not IsMoving?):
            set IsMoving = true

            Keys := 
                if(IsFlipped?):
                    set IsFlipped = false
                    array:
                        keyframed_movement_delta:
                            Duration := Duration
                            Transform := transform:
                                Translation := vector3{}
                                Rotation := Flip.Invert()
                                Scale := vector3{}
                else:
                    set IsFlipped = true
                    array:
                        keyframed_movement_delta:
                            Duration := Duration
                            Transform := transform:
                                Translation := vector3{}
                                Rotation := Flip
                                Scale := vector3{}

            MovementComponent.SetKeyframes(Keys, oneshot_keyframed_movement_playback_mode{})
            MovementComponent.Play()
            MovementComponent.FinishedEvent.Await()
            
            set IsMoving = false

    OnBeginSimulation<override>():void=
        if(TargetComponent := Entity.GetComponent[keyframed_movement_component]):
            set MovementComponent = TargetComponent
        else:
            NewComponent := keyframed_movement_component{Entity := Entity}
            Entity.AddComponents(array{NewComponent})
            set MovementComponent = NewComponent

        if(FortRoundManager := Entity.GetFortRoundManager[]):
            FortRoundManager.SubscribeRoundStarted(OnRoundStarted)

    OnRoundStarted():void=
        if(FortPlayspace := Entity.GetPlayspaceForEntity[]):
            for(Player : FortPlayspace.GetPlayers()):
                OnPlay(Player)

            FortPlayspace.PlayerAddedEvent().Subscribe(OnPlay)
            FortPlayspace.PlayerRemovedEvent().Subscribe(OnLeave)

    OnPlay(Player:player):void=
        if(FortCharacter := Player.GetFortCharacter[]):
            JumpedEvent := FortCharacter.JumpedEvent().Subscribe(OnJumped)
            if(set JumpedEventMap[Player] = JumpedEvent){}

    OnLeave(Player:player):void=
        if(JumpedEvent := JumpedEventMap[Player]):
            JumpedEvent.Cancel()

            var NewJumpedEventMap:[player]cancelable = map{}
            for:
                Key -> Value : JumpedEventMap
                Key <> Player
                set NewJumpedEventMap[Key] = Value
            do:
            set JumpedEventMap = NewJumpedEventMap

    OnJumped(FortCharacter:fort_character):void=
        spawn{Toggle()}